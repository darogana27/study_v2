locals {
  # スケジューラー共通設定
  scheduler_config = {
    data_collection_interval = "rate(10 minutes)"
    timezone                 = "Asia/Tokyo"
  }
}

module "parking_data_scheduler" {
  source = "../../modules/aws/eventbridge/scheduler"

  product    = local.env.product
  account_id = local.env.account_id
  region     = local.env.region

  schedules = {
    parking-data-collector = {
      description          = "Collect parking data every ${local.scheduler_config.data_collection_interval}"
      use_step_function    = false
      flexible_time_window = "OFF"
      schedule_expression  = local.scheduler_config.data_collection_interval
      target_arn           = module.lambda_functions.arns["parking-data-collector"]
      input_message_body   = ""
      input_queue_url      = ""
      additional_policies  = []
    }
  }
}