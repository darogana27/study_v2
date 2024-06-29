variable "schedule_name" {
  description = "スケジュール名"
  type        = string
}

variable "flexible_time_window" {
  description = "スケジュールの実行時間に柔軟性を持たせる場合がはONに"
  default     = "OFF"
  type        = string
}

variable "schedule_expression" {
  description = "スケジュールの設定"
  default     = "cron(0 21 * * ? *)"
  type        = string
}

variable "target_arn" {
  description = "ターゲットにするリソースのARN"
  type        = string
  default = null
}

variable "role_arn" {
  description = "IAM Role名"
  type        = string
}

variable "input_message_body" {
  description = "メッセージを指定する場合に指定"
  type        = string
  default     = ""
}

variable "input_queue_url" {
  description = "キューのURLを指定"
  type        = string
  default     = ""
}