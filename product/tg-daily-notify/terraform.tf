terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = " ~> 5.0"
    }
  }

  backend "s3" {
    bucket       = "terraform-state-2024-0218"
    region       = "ap-northeast-1"
    key          = "amount-of-electicity-terraform.tfstate"
    use_lockfile = true
  }
}

provider "aws" {
  region = "ap-northeast-1"

  default_tags {
    tags = {
      product = "tg-daily-notify"
      created = "terraform"
    }
  }
}
