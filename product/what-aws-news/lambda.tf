module "lambda_functions" {
  source = "../../modules/aws/lambda"

  product = local.env.product
  lambda_functions = {
    fetch = {
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
    translate = {
      memory_size      = 512
      timeout          = 150
      delay_seconds    = 90
      need_sqs_trigger = true
      sqs_config = {
        delay_seconds    = 0
        max_message_size = 262144
      }
      reserved_concurrent_executions = "1"
      additional_iam_policies = [
        {
          effect = "Allow"
          actions = [
            "dynamodb:PutItem",
            "dynamodb:UpdateItem",
            "dynamodb:GetItem",
            "dynamodb:DeleteItem",
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