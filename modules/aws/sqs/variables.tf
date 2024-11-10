variable "sqs" {
  type = map(any)
}

variable "delay_seconds" {
  type    = number
  default = 90
}

variable "max_message_size" {
  type    = number
  default = 2048
}

variable "message_retention_seconds" {
  type    = number
  default = 86400
}

variable "receive_wait_time_seconds" {
  type    = number
  default = 10
}
variable "visibility_timeout_seconds" {
  type        = number
  description = "Lambda 関数のタイムアウトを SQS の visibility timeout に使用"
}