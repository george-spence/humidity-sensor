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

# Allow HTTPS outbound for SSM Session Manager
resource "aws_vpc_security_group_egress_rule" "ssm" {
  security_group_id = aws_security_group.cloudflare_ztna_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
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

# https://github.com/cloudflare/terraform-provider-cloudflare/issues/6006
data "cloudflare_zero_trust_access_applications" "warp" {
  account_id = var.cloudflare_account_id
  name     = "Warp Login App"
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

resource "cloudflare_zero_trust_access_application" "warp" {
  account_id = var.cloudflare_account_id
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

resource "cloudflare_zero_trust_device_settings" "enable_gateway" {
  account_id                = var.cloudflare_account_id
  gateway_proxy_enabled     = true
  gateway_udp_proxy_enabled = true

  # Required due to Cloudflare provider errors
  disable_for_time                      = 0
  root_certificate_installation_enabled = false
  use_zt_virtual_ip                     = false
}

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

  identity = join(" or ", [for e in var.allowed_emails : "identity.email == \"${e}\""])
  traffic = "net.dst.ip == 0.0.0.0"  # always true
}

# Allow any enrolled device to reach port 1883 (Mosquitto MQTT).
# identity.service_token_uuid is not a valid L4 selector, so this is an
# intentionally broad rule — the catch-all block below provides the restriction.
resource "cloudflare_zero_trust_gateway_policy" "pi_allow_mqtt" {
  account_id  = var.cloudflare_account_id
  name        = "${var.project_name}-pi-allow-mqtt"
  description = "Allow any enrolled device to reach Mosquitto on TCP 1883"
  enabled     = true
  precedence  = 20
  action      = "allow"
  filters     = ["l4"]

  traffic = "net.dst.port == 1883"
}

# Default deny: block all other ports for any identity not already matched above.
# Users are passed through at precedence 10 before reaching this rule.
# Non-user devices (e.g. Pi) that are not going to port 1883 are blocked here.
resource "cloudflare_zero_trust_gateway_policy" "pi_block_other" {
  account_id  = var.cloudflare_account_id
  name        = "${var.project_name}-block-default"
  description = "Default deny all traffic not matched by higher-precedence allow rules"
  enabled     = true
  precedence  = 30
  action      = "block"
  filters     = ["l4"]

  traffic = "net.dst.ip == 0.0.0.0"  # always true
}
