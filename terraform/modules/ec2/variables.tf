variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment (dev/prod)"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-2"
}

variable "secret_arns" {
  description = "ARNs of SSM parameters the instance may read"
  type        = list(string)
}

variable "vpc_security_group_ids" {
  description = "Security group IDs to associate with the instance"
  type        = list(string)
}

variable "subnet_id" {
  description = "Private subnet to launch instances into"
  type        = string
}

variable "s3_config_bucket_arn" {
  description = "ARN of the S3 bucket containing config files"
  type        = string
}

variable "s3_config_bucket_name" {
  description = "Name of the S3 bucket containing config files"
  type        = string
}
