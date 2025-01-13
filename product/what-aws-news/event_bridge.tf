module "schedulers" {
  source  = "../../modules/aws/eventbridge/scheduler"
  product = local.env.product
  schedules = {
    translate = {
      use_step_function = true
    },
    get_all_tag_services = {
      use_step_function   = true
      schedule_expression = "cron(55 23 1 * ? *)" # 毎月1日23時55分実行
    },
  }
  account_id = data.aws_caller_identity.self.account_id
  region     = data.aws_region.self.name
}