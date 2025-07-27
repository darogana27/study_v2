locals {
  env = {
    product     = "pfc"
    environment = "prod"
    region      = data.aws_region.self.name
    account_id  = data.aws_caller_identity.self.account_id
  }

  # 共通リソース名
  dynamodb_table_name = "${local.env.product}-ParkingSpots-table"

  # Lambda共通設定
  lambda_common = {
    runtime = "python3.13"
    timeout = 30
    environment_variables = {
      DYNAMODB_TABLE_NAME   = local.dynamodb_table_name
      ENVIRONMENT           = local.env.environment
      ENABLE_SELECTION_MODE = "true"
      MAX_BEDROCK_TOKENS    = "150"
    }

    # DynamoDB共通権限
    dynamodb_permissions = {
      effect = "Allow"
      actions = [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:UpdateItem",
        "dynamodb:Scan",
        "dynamodb:Query",
        "dynamodb:BatchWriteItem"
      ]
      resources = ["arn:aws:dynamodb:${local.env.region}:${local.env.account_id}:table/${local.env.product}*"]
    }

    # CloudWatch Logs権限
    cloudwatch_permissions = {
      effect = "Allow"
      actions = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
      resources = ["arn:aws:logs:${local.env.region}:${local.env.account_id}:*"]
    }
  }
}