variable "sqs" {
  description = "SQS configurations"
  type = map(object({
    delay_seconds              = optional(number, 90)
    max_message_size           = optional(number, 262144)
    message_retention_seconds  = optional(number, 86400)
    receive_wait_time_seconds  = optional(number, 10)
    visibility_timeout_seconds = optional(number, 10)
  }))
}