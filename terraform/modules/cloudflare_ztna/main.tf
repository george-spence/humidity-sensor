terraform {
  required_providers {
    cloudflare = {
      source = "cloudflare/cloudflare"
    }
  }
}

################################################################################
# AWS - Security Group
################################################################################

# Runtime SG: replaces the bootstrap SG once cloud-init completes.
# Only allows the egress needed for ongoing tunnel operation.
resource "aws_security_group" "cloudflare_ztna_sg" {
  name        = "cloudflare_ztna_sg"
  description = "Runtime - Cloudflare tunnel egress only"
  vpc_id      = var.vpc_id

  tags = {
    Name = "cloudflare_ztna_sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# UDP 7844: primary QUIC port for the cloudflared outbound tunnel connection.
resource "aws_vpc_security_group_egress_rule" "cloudflare_udp" {
  for_each = toset(var.cloudflare_ips)

  security_group_id = aws_security_group.cloudflare_ztna_sg.id
  cidr_ipv4         = "${each.value}/32"
  ip_protocol       = "udp"
  from_port         = 7844
  to_port           = 7844
}

# TCP 7844: cloudflared fallback when UDP 7844 is unavailable.
resource "aws_vpc_security_group_egress_rule" "cloudflare_tcp" {
  for_each = toset(var.cloudflare_ips)

  security_group_id = aws_security_group.cloudflare_ztna_sg.id
  cidr_ipv4         = "${each.value}/32"
  ip_protocol       = "tcp"
  from_port         = 7844
  to_port           = 7844
}

################################################################################
# AWS - SSM Parameters
################################################################################

resource "aws_ssm_parameter" "tunnel_token" {
  name        = "/${var.project_name}/${var.environment}/cloudflare/tunnel_token"
  description = "Cloudflared tunnel token for EC2 connector"
  type        = "SecureString"
  value       = data.cloudflare_zero_trust_tunnel_cloudflared_token.ec2_tunnel.token

  tags = {
    Name        = "Cloudflare Tunnel Token"
    Environment = var.environment
  }
}

resource "aws_ssm_parameter" "pi_service_token_client_id" {
  name        = "/${var.project_name}/${var.environment}/cloudflare/pi_service_token_client_id"
  description = "Cloudflare Access service token client ID for Raspberry Pi"
  type        = "SecureString"
  value       = cloudflare_zero_trust_access_service_token.pi.client_id

  tags = {
    Name        = "Pi Service Token Client ID"
    Environment = var.environment
  }
}

resource "aws_ssm_parameter" "pi_service_token_client_secret" {
  name        = "/${var.project_name}/${var.environment}/cloudflare/pi_service_token_client_secret"
  description = "Cloudflare Access service token client secret for Raspberry Pi"
  type        = "SecureString"
  value       = cloudflare_zero_trust_access_service_token.pi.client_secret

  tags = {
    Name        = "Pi Service Token Client Secret"
    Environment = var.environment
  }
}

################################################################################
# Cloudflare - Tunnel
################################################################################

resource "cloudflare_zero_trust_tunnel_cloudflared" "ec2_tunnel" {
  account_id = var.cloudflare_account_id
  name       = "${var.project_name}-ec2-tunnel"
}

data "cloudflare_zero_trust_tunnel_cloudflared_token" "ec2_tunnel" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.ec2_tunnel.id
}

resource "cloudflare_zero_trust_tunnel_cloudflared_route" "vpc" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.ec2_tunnel.id
  network    = var.vpc_cidr
}

################################################################################
# Cloudflare - Device Profiles
################################################################################

# Split tunnel in "include" mode: only VPC traffic routes through WARP.
# Enrolled laptops access private EC2 IPs; all other traffic is direct.
resource "cloudflare_zero_trust_device_custom_profile" "users" {
  account_id  = var.cloudflare_account_id
  name        = "${var.project_name}-users"
  description = "WARP profile for authorized laptop users"
  match       = join(" or ", [for e in var.allowed_emails : "identity.email == \"${e}\""])
  precedence  = 10
  enabled     = true

  include = [
    {
      address     = var.vpc_cidr
      description = "VPC network"
    }
  ]
}

# Profile for Raspberry Pi, matched by its service token identity.
resource "cloudflare_zero_trust_device_custom_profile" "pi" {
  account_id  = var.cloudflare_account_id
  name        = "${var.project_name}-pi"
  description = "WARP profile for Raspberry Pi sensor device"
  match       = "identity.service_token_uuid == \"${cloudflare_zero_trust_access_service_token.pi.id}\""
  precedence  = 20
  enabled     = true

  include = [
    {
      address     = var.vpc_cidr
      description = "VPC network"
    }
  ]
}

################################################################################
# Cloudflare - Service Token (Raspberry Pi)
################################################################################

resource "cloudflare_zero_trust_access_service_token" "pi" {
  account_id = var.cloudflare_account_id
  name       = "${var.project_name}-pi-service-token"
  duration   = "8760h"
}

################################################################################
# Cloudflare - WARP Enrollment Application & Policies
################################################################################

data "cloudflare_access_application" "warp_enrollment" {
  account_id = var.cloudflare_account_id
  name       = "WARP"
}

# Allow the Raspberry Pi (service token) to enroll in WARP.
resource "cloudflare_zero_trust_access_policy" "warp_enrollment_pi" {
  account_id = var.cloudflare_account_id
  name       = "${var.project_name}-device-enrollment-pi"
  decision   = "non_identity"

  include = [
    {
      service_token = {
        token_id = cloudflare_zero_trust_access_service_token.pi.id
      }
    }
  ]
}

# Allow authorized laptop users (by email) to enroll in WARP.
resource "cloudflare_zero_trust_access_policy" "warp_enrollment_users" {
  account_id = var.cloudflare_account_id
  name       = "${var.project_name}-device-enrollment-users"
  decision   = "allow"

  include = [for e in var.allowed_emails : { email = { email = e } }]
}

resource "cloudflare_zero_trust_access_application" "warp_enrollment" {
  account_id = var.cloudflare_account_id
  name       = "WARP"
  type       = "warp"

  policies = [
    {
      id         = cloudflare_zero_trust_access_policy.warp_enrollment_pi.id
      precedence = 1
    },
    {
      id         = cloudflare_zero_trust_access_policy.warp_enrollment_users.id
      precedence = 2
    }
  ]

  lifecycle {
    prevent_destroy = true
  }
}

################################################################################
# Cloudflare - Gateway Network Policies
################################################################################

# Authorized users get unrestricted access to all VPC ports.
# Must be evaluated before the Pi-restrict policies (lower precedence = first).
resource "cloudflare_zero_trust_gateway_policy" "users_allow_all" {
  account_id  = var.cloudflare_account_id
  name        = "${var.project_name}-users-allow-all"
  description = "Allow authorized users unrestricted VPC access"
  enabled     = true
  precedence  = 10
  action      = "allow"
  filters     = ["l4"]

  traffic = join(" or ", [for e in var.allowed_emails : "identity.email == \"${e}\""])
}

# Allow the Pi to reach only port 1883 (Mosquitto MQTT over TCP).
resource "cloudflare_zero_trust_gateway_policy" "pi_allow_mqtt" {
  account_id  = var.cloudflare_account_id
  name        = "${var.project_name}-pi-allow-mqtt"
  description = "Allow Pi service token to reach Mosquitto on TCP 1883 only"
  enabled     = true
  precedence  = 20
  action      = "allow"
  filters     = ["l4"]

  traffic = "net.dst.port == 1883 and identity.service_token_uuid == \"${cloudflare_zero_trust_access_service_token.pi.id}\""
}

# Block the Pi from all other VPC ports. Evaluated after the allow-1883 rule so
# it acts as a catch-all for the Pi identity.
resource "cloudflare_zero_trust_gateway_policy" "pi_block_other" {
  account_id  = var.cloudflare_account_id
  name        = "${var.project_name}-pi-block-other"
  description = "Block Pi service token from all VPC ports except 1883"
  enabled     = true
  precedence  = 30
  action      = "block"
  filters     = ["l4"]

  traffic = "identity.service_token_uuid == \"${cloudflare_zero_trust_access_service_token.pi.id}\""
}
