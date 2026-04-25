terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>6.30.0"
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
