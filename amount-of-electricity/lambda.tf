module "lambda_functions" {
  source = "../modules/lambda"

  lambda_functions = {
    daily_electricity = {
      function_name = "daily_electricity"
      image_uri     = data.aws_ssm_parameter.ecr_daily_electricity_image_url.value
      memory_size   = 512
      additional_iam_policies = [
        {
          effect    = "Allow"
          actions   = ["s3:PutObject"]
          resources = ["arn:aws:s3:::amount-of-electricity-bucket/*"]
        },
      ]
    }
    line_notify = {
      function_name = "line_notify"
      filename      = "./lambda/Line_Notify.zip"
      additional_iam_policies = [
        {
          effect    = "Allow"
          actions   = ["s3:GetObject"]
          resources = ["arn:aws:s3:::amount-of-electricity-bucket/*"]
        },
      ]
    },
  }
}

output "lambda_arns" {
  value       = module.lambda_functions.lambda_arns
  description = "各Lambda関数のARN"
}


