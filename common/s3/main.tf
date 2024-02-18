provider "aws" {
    region = "ap-northeast-1"
}

module "state_s3" {
  source         = "../../modules/s3"
  s3_bucket_name = "terraform-state-2024-0218"
}

module "apilambda_s3" {
  source         = "../../modules/s3"
  s3_bucket_name = "lambda-package-2024-0218"
}

resource "aws_dynamodb_table" "terraform-locks" {
  name = "terraform-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}


terraform {
  backend "s3" {
    bucket = "terraform-state-2024-0218"
    key = "common/s3/terraform.tfstate"
    region = "ap-northeast-1"

    dynamodb_table = "terraform-locks"
    encrypt = true
  }
}