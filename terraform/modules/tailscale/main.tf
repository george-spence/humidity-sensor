resource "tailscale_tailnet_key" "ec2" {
  reusable      = true
  ephemeral     = false
  preauthorized = true
  description   = "${var.project_name}-ec2"
}

resource "aws_ssm_parameter" "tailnet_key" {
  name        = "/${var.project_name}/${var.environment}/tailscale/tailnet_key"
  description = "Tailscale auth key for EC2 node enrollment"
  type        = "SecureString"
  value       = tailscale_tailnet_key.ec2.key

  tags = {
    Name        = "Tailscale Auth Key"
    Environment = var.environment
  }
}
