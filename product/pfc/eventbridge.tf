module "parking_data_scheduler" {
  source = "../../modules/aws/eventbridge/scheduler"

  product    = local.env.product
  account_id = local.env.account_id
  region     = local.env.region

  schedules = {
    parking-data-collector = {
      use_step_function    = false
      flexible_time_window = "OFF"
      schedule_expression  = "rate(10 minutes)"
      target_arn           = module.lambda_functions.arns["parking-data-collector"]
      input_message_body   = ""
      input_queue_url      = ""
      additional_policies  = []
    }
  }
}