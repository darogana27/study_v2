module "sqs" {
  source = "../../modules/aws/sqs"

  product = "{{PRODUCT_NAME}}"
  sqs     = var.sqs
}

variable "sqs" {
  description = "SQS queues configuration"
  type = map(object({
    delay_seconds              = optional(number, 0)
    max_message_size           = optional(number, 262144)
    message_retention_seconds  = optional(number, 345600)
    receive_wait_time_seconds  = optional(number, 0)
    visibility_timeout_seconds = optional(number, 30)
    max_receive_count          = optional(number, 4)
  }))
  default = {}
}