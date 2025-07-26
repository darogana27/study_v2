terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "{{REGION}}"
  default_tags {
    tags = {
      Product = "{{PRODUCT_NAME}}"
    }
  }
}