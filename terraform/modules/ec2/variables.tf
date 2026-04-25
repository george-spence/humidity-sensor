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
  description = "ARNs of SSM Parameter secrets which EC2 can access"
  type        = list(string)
}

variable "vpc_security_group_ids" {
  description = "IDs of the VPC security groups to associate"
  type        = list(string)
}

variable "subnet_id" {
  description = "Subnet to launch the instance in"
  type        = string
}

variable "s3_config_bucket_arn" {
  description = "ARN of bucket containing config files to be used by the instance"
  type = string
}

variable "s3_config_bucket_name" {
  description = "Name of bucket containing config files to be used by the instance"
  type = string
}
