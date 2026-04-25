variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment (dev/prod)"
  type        = string
}

variable "secrets" {
  description = "Map of secrets to store in SSM Parameter Store"
  type = map(object({
    value       = string
    description = string
  }))
}
