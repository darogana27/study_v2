module "eventbridge" {
  source        = "../modules/eventbridge/scheduler"
  schedule_name = "amount-of-electricity"
  target_arn    = module.step_function.state_machine_arn
  role_arn      = module.eventbridge_role.role_arn
}