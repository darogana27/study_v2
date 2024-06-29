module "eventbridge_role" {
  source        = "../modules/eventbridge/iam"
  schedule_name = "amount-of-electricity"
  target_arn    = module.step_function.state_machine_arn
}

output "scheduler_role_arn" {
  value       = module.eventbridge_role.role_arn
  description = "Scheduler IAM Role ARN"
}