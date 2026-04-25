output "cloudflare_ztna_sg_id" {
  description = "ID of security group with egress to Cloudflare ZTNA IPs"
  value       = aws_security_group.cloudflare_ztna_sg.id
}

output "pi_service_token_ssm_paths" {
  description = "SSM parameter paths for the Pi's Cloudflare service token credentials"
  value = {
    client_id     = aws_ssm_parameter.pi_service_token_client_id.name
    client_secret = aws_ssm_parameter.pi_service_token_client_secret.name
  }
}
