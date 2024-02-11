provider aws {
    region = "ap-northeast-1"
}

terraform {
  backend "s3" {
    bucket = "terraform-state-2024-0211"
    key = "videos/s3/terraform.tfstate"
    region = "ap-northeast-1"

    dynamodb_table = "terraform-locks"
    encrypt = true
  }
}