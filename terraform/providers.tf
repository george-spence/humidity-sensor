provider "aws" {
  profile = "default"
  region  = "eu-west-2"

  default_tags {
    tags = {
      Environment = "Production"
      ManagedBy   = "Terraform"
      Project     = "humidity-sensor"
    }
  }
}
