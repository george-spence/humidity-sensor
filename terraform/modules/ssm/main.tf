data "aws_kms_key" "ssm_default" {
  key_id = "alias/aws/ssm"
}

resource "aws_ssm_parameter" "secrets" {
  for_each = var.secrets

  name        = "/${var.project_name}/${var.environment}/${each.key}"
  description = lookup(each.value, "description", "Secret for ${each.key}")
  type        = "SecureString"
  value       = each.value.value

  tags = {
    Name        = each.key
    Environment = var.environment
  }
}

locals {
  secret_arns = [for s in aws_ssm_parameter.secrets : s.arn]
}
