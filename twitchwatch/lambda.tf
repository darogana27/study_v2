module "lambda_functions" {
  source = "../modules/lambda"

  lambda_functions = {
    twitch-api-data-collector = {
      function_name = "twitch-api-data-collector"
      filename      = "./lambda/twitch-api-data-collector.zip"
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
      ]
    },
  }
}

output "lambda_arns" {
  value       = module.lambda_functions.lambda_arns
  description = "各Lambda関数のARN"
}


