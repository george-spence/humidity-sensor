terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
    }
  }
}

################################################################################
# AWS Setup
################################################################################

resource "aws_security_group" "cloudflare_ztna_sg" {
    name        = "cloudflare_ztna_sg"
    description = "Allow egress to Cloudflare ZTNA IPs"
    vpc_id      = var.vpc_id

    tags = {
        Name = "cloudflare_ztna_sg"
    }

    lifecycle {
        create_before_destroy = true
    }
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4" {
  for_each = toset(var.cloudflare_ips)

  security_group_id = aws_security_group.cloudflare_ztna_sg.id
  cidr_ipv4         = "${each.value}/32"
  ip_protocol       = "udp"
}

################################################################################
# Cloudflare
################################################################################

resource "random_bytes" "tunnel_secret" {
  length = 32
}

resource "aws_ssm_parameter" "secrets" {
  name        = "/${var.project_name}/${var.environment}/cloudflare/tunnel_secret"
  description = "Cloudflared tunnel secret"
  type        = "SecureString"
  value       = random_bytes.tunnel_secret.base64

  tags = {
    Name        = "Cloudflare Tunnel Secret"
    Environment = var.environment
  }
}

resource "cloudflare_zero_trust_tunnel_cloudflared" "ec2_tunnel" {
  account_id    = var.cloudflare_account_id
  name          = "ec2-tunnel"
  tunnel_secret = random_bytes.tunnel_secret.base64
}

resource "cloudflare_zero_trust_tunnel_cloudflared_route" "vpc" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.ec2_tunnel.id
  network    = "10.0.0.0/16"
}
################## TODO
################## TO BE VALIDATED. Also need to do for_each for emails

# resource "cloudflare_zero_trust_device_custom_profile" "warp_access" {
#   account_id = var.cloudflare_account_id
#   name       = "allow-my-email"
#   precedence = 1

#   match = "identity.email == \"you@example.com\""
# }

# resource "cloudflare_zero_trust_device_settings" "default" {
#   account_id = var.cloudflare_account_id

#   gateway_proxy_enabled              = true
#   gateway_udp_proxy_enabled          = true
#   root_certificate_installation_enabled = true
# }

# resource "cloudflare_zero_trust_gateway_dns_policy" "internal_dns" {
#   account_id = var.account_id
#   name       = "internal-app"
#   precedence = 1
#   action     = "allow"

#   filters = ["dns"]
#   traffic = "dns.name == \"app.internal\""

#   rule_settings {
#     override_host = "10.0.0.5"
#   }
# }