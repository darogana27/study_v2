module "lambda_functions" {
  source = "../../../modules/aws/lambda"

  product = local.env.product
  lambda_functions = {
    park-finder-chat = {
      filename    = "../src/lambda/builds/lambda_function.zip"
      handler     = "park-finder-chat.lambda_handler"
      runtime     = local.lambda_common.runtime
      memory_size = 256
      timeout     = local.lambda_common.timeout
      description = "PFC Park Finder Chat Function"

      environment_variables = merge(local.lambda_common.environment_variables, {
        BEDROCK_MODEL_ID = "anthropic.claude-3-sonnet-20240229-v1:0"
      })

      additional_iam_policies = [
        local.lambda_common.dynamodb_permissions,
        local.lambda_common.cloudwatch_permissions,
        {
          effect = "Allow"
          actions = [
            "bedrock:InvokeModel"
          ]
          resources = ["arn:aws:bedrock:ap-northeast-1:*:model/anthropic.claude-3-sonnet*"]
        }
      ]
    }

    parking-data-collector = {
      filename    = "../src/lambda/builds/parking-data-collector.zip"
      handler     = "parking-data-collector.lambda_handler"
      runtime     = local.lambda_common.runtime
      memory_size = 128
      timeout     = 60
      description = "PFC Parking Data Collector Function"

      environment_variables = local.lambda_common.environment_variables

      additional_iam_policies = [
        local.lambda_common.dynamodb_permissions,
        local.lambda_common.cloudwatch_permissions
      ]
    }

    parking-spots-api = {
      filename    = "../src/lambda/builds/parking-spots-api.zip"
      handler     = "parking-spots-api.lambda_handler"
      runtime     = local.lambda_common.runtime
      memory_size = 128
      timeout     = 30
      description = "PFC Parking Spots API Function"

      environment_variables = local.lambda_common.environment_variables

      additional_iam_policies = [
        local.lambda_common.dynamodb_permissions,
        local.lambda_common.cloudwatch_permissions
      ]
    }
  }
}