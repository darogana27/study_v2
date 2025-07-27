terraform {
  required_version = ">= 1.0"

  backend "s3" {
    bucket       = "terraform-state-2024-0218"
    key          = "common/main.tfstate"
    region       = "ap-northeast-1"
    encrypt      = true
    use_lockfile = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-northeast-1"

  default_tags {
    tags = {
      ManagedBy = "Terraform"
      Project   = "common"
    }
  }
}