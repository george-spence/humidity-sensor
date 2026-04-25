output "secret_arns" {
  description = "ARNs of SSM Parameter secrets which ASG can access"
  value       = local.secret_arns
}