module "schedulers" {
  source = "../../modules/aws/eventbridge/scheduler"

  schedules = {
    twitch-rotation = {
      target_arn = module.lambda_functions.arns["twitch-rotation"]
      #   schedule_expression = "cron(0 0 1/2 * ? *)"
      schedule_expression = "cron(35 * * * ? *)"
      additional_policies = [
        {
          effect    = "Allow"
          actions   = ["lambda:InvokeFunction"]
          resources = ["arn:aws:lambda:${data.aws_region.self.name}:${data.aws_caller_identity.self.account_id}:function:twitch-rotation-function"]
        }
      ]
    },
  }
  account_id = data.aws_caller_identity.self.account_id
  region     = data.aws_region.self.name
}