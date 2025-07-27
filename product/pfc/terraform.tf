terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {
    bucket = "terraform-state-2024-0218"
    region = "ap-northeast-1"
    key    = "product/pfc.tfstate"
  }
}

provider "aws" {
  region = "ap-northeast-1"
  default_tags {
    tags = {
      Product = "pfc"
    }
  }
}