variable "schedule_name" {
  description = "スケジュール名"
  type        = string
}

variable "target_arn" {
  description = "ターゲットにするリソースのARN"
  type        = string
  default = null
}
