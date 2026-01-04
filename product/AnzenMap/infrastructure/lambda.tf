module "lambda" {
  source = "../../modules/aws/lambda"

  product           = "{{PRODUCT_NAME}}"
  lambda_functions  = var.lambda_functions
}

variable "lambda_functions" {
  description = "Lambda functions configuration"
  type = map(object({
    runtime                        = string
    handler                        = string
    timeout                        = optional(number, 30)
    memory_size                    = optional(number, 128)
    filename                       = optional(string)
    s3_bucket                      = optional(string)
    s3_key                         = optional(string)
    s3_object_version              = optional(string)
    image_uri                      = optional(string)
    package_type                   = optional(string, "Zip")
    architectures                  = optional(list(string), ["x86_64"])
    environment_variables          = optional(map(string), {})
    reserved_concurrent_executions = optional(number, -1)
    dead_letter_queue_target_arn   = optional(string)
    layers                         = optional(list(string), [])
    policy_arn                     = optional(list(string), [])
    policy_json                    = optional(string)
    event_source_mapping = optional(map(object({
      event_source_arn   = string
      function_name      = string
      starting_position  = optional(string, "LATEST")
      batch_size         = optional(number, 100)
      enabled            = optional(bool, true)
    })), {})
  }))
  default = {}
}