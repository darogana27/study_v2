terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = " ~> 5.0"
    }
  }

  backend "s3" {
    bucket = "terraform-state-2024-0218"
    region = "ap-northeast-1"
    key    = "twitchwatch-terraform.tfstate"
  }
}