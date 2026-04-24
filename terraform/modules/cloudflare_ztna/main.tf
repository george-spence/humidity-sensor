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

resource "aws_ssm_parameter" "secrets" {
  name        = "/${var.project_name}/${var.environment}/cloudflare/tunnel_secret"
  description = "Cloudflared tunnel secret"
  type        = "SecureString"
  value       = cloudflare_zero_trust_tunnel_cloudflared.ec2_tunnel.secret

  tags = {
    Name        = "Cloudflare Tunnel Secret"
    Environment = var.environment
  }
}

data "cloudflare_zero_trust_tunnel_cloudflared_token" "example_zero_trust_tunnel_cloudflared_token" {
  account_id = var.cloudflare_account_id
  tunnel_id = cloudflare_zero_trust_tunnel_cloudflared.ec2_tunnel.id
}

resource "cloudflare_zero_trust_tunnel_cloudflared" "ec2_tunnel" {
  account_id    = var.cloudflare_account_id
  name          = "humidity-sensor-ec2-tunnel"
}

resource "cloudflare_zero_trust_tunnel_cloudflared_route" "vpc" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.ec2_tunnel.id
  network    = "10.0.0.0/16"
}