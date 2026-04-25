output "state_bucket_name" {
  description = "S3 bucket name for Terraform state"
  value       = aws_s3_bucket.terraform_state.id
}

output "state_bucket_arn" {
  description = "S3 bucket ARN"
  value       = aws_s3_bucket.terraform_state.arn
}

output "dynamodb_table_name" {
  description = "DynamoDB table name for state locking"
  value       = aws_dynamodb_table.terraform_locks.id
}

output "backend_config" {
  description = "Backend configuration to use in main project"
  # Use a heredoc multiline string to store main projects backend.tf file
  value = <<-EOT
    terraform {
      backend "s3" {
        bucket = "${aws_s3_bucket.terraform_state.id}"
        key = "humidity-sensor/terraform.tfstate"
        region = "${var.aws_region}"
        encrypt = true
        dynamodb_table = "${aws_dynamodb_table.terraform_locks.id}"
      }
    }
  EOT
}
