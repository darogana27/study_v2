module "schedulers" {
  source  = "../../modules/aws/eventbridge/scheduler"
  product = local.env.product
  schedules = {
    fetch = {
      use_step_function   = true
      schedule_expression = "cron(30 8 * * ? *)" # 毎日08時30分実行
    },
    notify = {
      use_step_function   = true
      schedule_expression = "cron(15 9 * * ? *)" # 毎日09時15分実行
    },
  }
  account_id = data.aws_caller_identity.self.account_id
  region     = data.aws_region.self.name
}