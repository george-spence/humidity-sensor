terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>6.30.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }

  backend "s3" {
    bucket         	   = "terraform-bucket-70803"
    key              	 = "main/terraform.tfstate"
    region         	   = "eu-west-2"
    encrypt        	   = true
    dynamodb_table     = "terraform-state-locks"
  }

  required_version = ">=1.14"
}

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

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

