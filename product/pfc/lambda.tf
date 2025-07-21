module "lambda_functions" {
  source = "../../modules/aws/lambda"

  product = local.env.product
  lambda_functions = {
    park-finder-chat = {
      memory_size = 512
      timeout     = 90
      additional_iam_policies = [
        {
          effect = "Allow"
          actions = [
            "dynamodb:PutItem",
          ]
          resources = ["arn:aws:dynamodb:${local.env.region}:${local.env.account_id}:table/${local.env.product}*"]
        },
      ]
    }
  }
}