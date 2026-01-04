terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "terraform-state-2024-0218"
    key            = "product/AnzenMap.tfstate"
    region         = "ap-northeast-1"
    encrypt        = true
    use_lockfile   = true
  }
}

provider "aws" {
  region = "ap-northeast-1"
  default_tags {
    tags = {
      Product = "AnzenMap"
    }
  }
}