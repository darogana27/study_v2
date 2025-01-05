module "lambda_functions" {
  source = "../../modules/aws/lambda"

  lambda_functions = {
    daily_electricity = {
      image_uri   = data.aws_ssm_parameter.ecr_daily_electricity_image_url.value
      memory_size = 512
      additional_iam_policies = [
        {
          effect = "Allow"
          actions = [
            "dynamodb:PutItem",
            "dynamodb:UpdateItem",
            "dynamodb:GetItem",
            "dynamodb:Query",
            "dynamodb:Scan",
          ]
          resources = ["arn:aws:dynamodb:${local.env.region}:${local.env.account_id}:table/tg-daily-notify-table"]
        },
      ]
    }
    line_notify = {
      function_name = "line_notify"
      filename      = "./lambda/Line_Notify.zip"
      additional_iam_policies = [
        {
          effect = "Allow"
          actions = [
            "dynamodb:GetItem",
            "dynamodb:Query"
          ]
          resources = ["arn:aws:dynamodb:${local.env.region}:${local.env.account_id}:table/tg-daily-notify-table"]
        },
      ]
    },
  }
}


