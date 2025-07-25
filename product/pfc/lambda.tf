module "lambda_functions" {
  source = "../../modules/aws/lambda"

  product = local.env.product
  lambda_functions = {
    park-finder-chat = {
      filename    = "./lambda/lambda_function.zip"
      handler     = "park-finder-chat.lambda_handler"
      runtime     = "python3.13"
      memory_size = 256
      timeout     = 30
      description = "PFC Park Finder Chat Function"

      environment_variables = {
        DYNAMODB_TABLE_NAME = "pfc-ParkingSpots-table"
        BEDROCK_MODEL_ID    = "anthropic.claude-3-sonnet-20240229-v1:0"
      }

      additional_iam_policies = [
        {
          effect = "Allow"
          actions = [
            "dynamodb:GetItem",
            "dynamodb:PutItem",
            "dynamodb:UpdateItem",
            "dynamodb:Scan",
            "dynamodb:Query"
          ]
          resources = ["arn:aws:dynamodb:${local.env.region}:${local.env.account_id}:table/${local.env.product}*"]
        },
        {
          effect = "Allow"
          actions = [
            "bedrock:InvokeModel"
          ]
          resources = ["arn:aws:bedrock:*:*:model/anthropic.claude-3-sonnet*"]
        }
      ]
    }

    parking-data-collector = {
      filename    = "./lambda/parking-data-collector.zip"
      handler     = "parking-data-collector.lambda_handler"
      runtime     = "python3.13"
      memory_size = 128
      timeout     = 60
      description = "PFC Parking Data Collector Function"

      environment_variables = {
        DYNAMODB_TABLE_NAME = "pfc-ParkingSpots-table"
      }

      additional_iam_policies = [
        {
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
        },
        {
          effect = "Allow"
          actions = [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents"
          ]
          resources = ["arn:aws:logs:${local.env.region}:${local.env.account_id}:*"]
        }
      ]
    }
  }
}