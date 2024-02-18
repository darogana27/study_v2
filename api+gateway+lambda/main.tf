provider "aws" {
  region = "ap-northeast-1"
}

resource "aws_lambda_function" "lambda-test" {
  function_name = "lambda-test"
  role          = "arn:aws:iam::671522354054:role/service-role/lambda-test-role-i43ocw46"
  #   filename = aws_s3_object.lambda-test
  s3_bucket = module.s3.s3_id
  s3_key    = "lambda-test.zip"
  handler   = "lambda_function.lambda_handler"
  runtime   = "python3.12"
}