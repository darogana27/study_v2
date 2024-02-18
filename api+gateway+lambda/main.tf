provider "aws" {
  region = "ap-northeast-1"
}

resource "aws_lambda_function" "lambda-test" {
  function_name = "lambda-test"
  role          = "arn:aws:iam::671522354054:role/service-role/lambda-test-role-i43ocw46"
  s3_bucket = data.terraform_remote_state.common.outputs.s3_bucket_arn
  s3_key    = "lambda-test.zip"
  handler   = "lambda_function.lambda_handler"
  runtime   = "python3.12"
}

resource "aws_apigatewayv2_api" "api-gateway-test" {
  name = "api-gateway-test"
  protocol_type = "HTTP"
}

terraform {
  backend "s3" {
    bucket = "terraform-state-2024-0218"
    key = "study_v2/api_gateway+lambda/terraform.tfstate"
    region = "ap-northeast-1"
  }
}

data "terraform_remote_state" "common" {
  backend = "s3"

  config = {
    bucket = "terraform-state-2024-0218"
    key    = "common/s3/terraform.tfstate"
    region = "ap-northeast-1"
  }
}