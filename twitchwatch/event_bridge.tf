# module "schedulers" {
#   source = "../modules/eventbridge/scheduler"

#   schedules = {
#     twitchwatch = {
#       schedule_name = "top_live_channels"
#       target_arn    = module.lambda_functions.lambda_arns.twitch-api-data-collector
#       schedule_expression  = "cron(0,10,20,30,40,50 * * * ? *)"
#       additional_policies = [
#         {
#           effect = "Allow"
#           actions = ["lambda:InvokeFunction"]
#           resources = ["arn:aws:lambda:${data.aws_region.self.name}:${data.aws_caller_identity.self.account_id}:function:twitch-api-data-collector-function"]
#         }
#       ]
#     },
#   }
#   account_id = data.aws_caller_identity.self.account_id
#   region     = data.aws_region.self.name
# }