module "lambda_functions" {
  source = "../../modules/aws/lambda"

  product = local.env.product
  lambda_functions = {
    fetch = {
      memory_size = 512
      timeout     = 180
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
    translate = {
      memory_size = 512
      timeout     = 180
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
        {
          effect = "Allow"
          actions = [
            "bedrock:InvokeModel",
          ]
          resources = ["arn:aws:bedrock:${local.env.region}::foundation-model/anthropic.claude*"]
        }
      ]
      need_sqs_trigger = true
    }
    notify = {
      additional_iam_policies = [
        {
          effect = "Allow"
          actions = [
            "dynamodb:UpdateItem",
            "dynamodb:GetItem",
            "dynamodb:Query",
            "dynamodb:Scan",
            "dynamodb:BatchWriteItem"
          ]
          resources = ["arn:aws:dynamodb:${local.env.region}:${local.env.account_id}:table/${local.env.product}*"]
        },
        {
          effect = "Allow"
          actions = [
            "iam:GenerateServiceLastAccessedDetails",
            "iam:GetServiceLastAccessedDetails"
          ]
          resources = ["*"]
        },
      ]
    },
  }
}