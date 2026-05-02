output "ssm_parameter_arn" {
  description = "ARN of the SSM parameter holding the Tailscale auth key"
  value       = aws_ssm_parameter.tailnet_key.arn
}
