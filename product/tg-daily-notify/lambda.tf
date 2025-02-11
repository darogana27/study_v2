module "lambda_functions" {
  source = "../../modules/aws/lambda"

  product = local.env.product

  lambda_functions = {
    electricity = {
      image_uri   = module.ecr.repository_urls["daily-electricity"]
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
          resources = ["arn:aws:dynamodb:${local.env.region}:${local.env.account_id}:table/${local.env.product}*"]
        },
      ]
    }
    line_notify = {
      filename = "./lambda/Line_Notify.zip"
      timeout  = 180
      additional_iam_policies = [
        {
          effect = "Allow"
          actions = [
            "dynamodb:GetItem",
            "dynamodb:Query"
          ]
          resources = ["arn:aws:dynamodb:${local.env.region}:${local.env.account_id}:table/${local.env.product}*"]
        },
      ]
    },
  }
}


