variable "schedules" {
  description = "スケジュールのリスト"
  type = map(object({
    flexible_time_window = optional(string, "OFF")
    schedule_expression  = optional(string, "cron(0 21 * * ? *)")
    target_arn           = string
    input_message_body   = optional(string, "")
    input_queue_url      = optional(string, "")
    additional_policies = optional(list(object({
      effect    = string
      actions   = list(string)
      resources = list(string)
    })), [])
  }))
}

variable "account_id" {
  description = "AWSアカウントID"
  type        = string
}

variable "region" {
  description = "AWSリージョン"
  type        = string
}