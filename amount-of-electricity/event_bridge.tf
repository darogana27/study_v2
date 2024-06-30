module "schedulers" {
  source = "../modules/eventbridge/scheduler"

  schedules = {
    amount-of-electricity = {
      schedule_name = "amount-of-electricity"
      target_arn    = module.state_machines.state_machine_arns[0]
    },
  }
  account_id = data.aws_caller_identity.self.account_id
  region     = data.aws_region.self.name
}