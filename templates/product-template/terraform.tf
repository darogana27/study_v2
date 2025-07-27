terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "{{terraform_state_bucket}}"
    key            = "{{tfstate_key}}"
    region         = "{{region}}"
    encrypt        = true
    use_lockfile   = true
  }
}

provider "aws" {
  region = "{{region}}"
  default_tags {
    tags = {
      Product = "{{name}}"
    }
  }
}