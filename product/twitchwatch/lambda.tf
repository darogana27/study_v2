module "lambda_functions" {
  source = "../../modules/aws/lambda"

  lambda_functions = {
    twitch-rotation = {
      filename = "../modules/lambda/default.zip"
      additional_iam_policies = [
        {
          effect : "Allow",
          actions : [
            "s3:PutObject",
            "s3:PutObjectAcl",
            "s3:ListBucket"
          ],
          resources : [
            "arn:aws:s3:::twitch-api-data-storage-bucket",
            "arn:aws:s3:::twitch-api-data-storage-bucket/*"
          ]
        },
        {
          effect : "Allow",
          actions : [
            "ssm:Putparameter",
          ],
          resources : [
            "*"
          ]
        },
      ]
    },
    twitch-api-get-stremers = {
      filename    = "../../modules/aws/lambda/default.zip"
      memory_size = 512
      additional_iam_policies = [
        # {
        #   effect : "Allow",
        #   actions : [
        #     "s3:PutObject",
        #     "s3:PutObjectAcl",
        #     "s3:ListBucket"
        #   ],
        #   resources : [
        #     "arn:aws:s3:::twitch-api-data-storage-bucket",
        #     "arn:aws:s3:::twitch-api-data-storage-bucket/*"
        #   ]
        # },
        {
          effect : "Allow",
          actions : [
            "dynamodb:*"
          ],
          resources : [
            "*"
          ]
        },
      ]
    },
    twitch-api-get-users = {
      filename = "../../modules/aws/lambda/default.zip"
      additional_iam_policies = [
      ]
    },
    twitch-api-get-games = {
      filename = "../modules/lambda/default.zip"
      additional_iam_policies = [
      ]
    },
    twitch-api-get-games-followers = {
      filename = "../../modules/aws/lambda/default.zip"
      additional_iam_policies = [
      ]
    },
  }
}

output "arns" {
  value       = module.lambda_functions.arns
  description = "各Lambda関数のARN"
}


