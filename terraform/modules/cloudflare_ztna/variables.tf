variable "vpc_id" {
  description = "ID of the VPC for the Cloudflare security group"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block, used for the tunnel route and device profile split tunnel rules"
  type        = string
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment (dev/prod)"
  type        = string
}

variable "allowed_emails" {
  description = "Email addresses permitted to access via WARP (laptop users)"
  type        = list(string)
  sensitive   = true
}

variable "cloudflare_account_id" {
  description = "ID of Cloudflare account"
  type        = string
  sensitive   = true
}

variable "cloudflare_ips" {
  description = "Cloudflare edge IPs to which UDP egress is required for tunnel operation"
  type        = list(string)
  default = [
    "198.41.192.167",
    "198.41.192.67",
    "198.41.192.57",
    "198.41.192.107",
    "198.41.192.27",
    "198.41.192.7",
    "198.41.192.227",
    "198.41.192.47",
    "198.41.192.37",
    "198.41.192.77",
    "198.41.200.13",
    "198.41.200.193",
    "198.41.200.33",
    "198.41.200.233",
    "198.41.200.53",
    "198.41.200.63",
    "198.41.200.113",
    "198.41.200.73",
    "198.41.200.43",
    "198.41.200.23"
  ]
}

variable "cloudflare_team_name" {
  description = "Name of the Cloudflare Zero Trust team"
  type        = string
  default     = null
}