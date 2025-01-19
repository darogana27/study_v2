module "schedulers" {
  source = "../../modules/aws/eventbridge/scheduler"

  product = local.env.product

  schedules = {
    line_notify = {
      use_step_function = true

    },
  }
  account_id = data.aws_caller_identity.self.account_id
  region     = data.aws_region.self.name
}