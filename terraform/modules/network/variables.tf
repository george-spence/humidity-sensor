variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment (dev/prod)"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
}

variable "public_subnet_cidr" {
  description = "VPC public subnet CIDR block"
  type        = string
}

variable "availability_zone" {
  description = "Availability zone for subnet"
  type        = string
}
