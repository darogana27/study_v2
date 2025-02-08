module "schedulers" {
  source  = "../../modules/aws/eventbridge/scheduler"
  product = local.env.product
  schedules = {
    translate = {
      use_step_function   = true
      schedule_expression = "cron(55 8 * * ? *)" # 毎日08時55分実行

    },
    fetch = {
      use_step_function   = true
      schedule_expression = "cron(55 8 * * ? *)" # 毎日08時55分実行
    },
    notify = {
      use_step_function   = true
      schedule_expression = "cron(15 9 * * ? *)" # 毎日08時55分実行
    },
  }
  account_id = data.aws_caller_identity.self.account_id
  region     = data.aws_region.self.name
}