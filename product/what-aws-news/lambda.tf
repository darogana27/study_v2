module "lambda_functions" {
  source = "../../modules/aws/lambda"

  product = local.env.product
  lambda_functions = {
    translate = {
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
        {
          effect = "Allow"
          actions = [
            "bedrock:InvokeModel",
          ]
          resources = ["arn:aws:bedrock:${local.env.region}::foundation-model/anthropic.claude*"]
        }
      ]
    }
    get_all_tag_services = {
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