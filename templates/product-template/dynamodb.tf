module "dynamodb" {
  source = "../../modules/aws/dynamodb"

  product    = "{{PRODUCT_NAME}}"
  dynamodbs  = var.dynamodbs
}

variable "dynamodbs" {
  description = "DynamoDB tables configuration"
  type = map(object({
    hash_key       = string
    range_key      = optional(string)
    billing_mode   = optional(string, "PAY_PER_REQUEST")
    read_capacity  = optional(number, 20)
    write_capacity = optional(number, 20)
    attributes = list(object({
      name = string
      type = string
    }))
    global_secondary_indexes = optional(list(object({
      name            = string
      hash_key        = string
      range_key       = optional(string)
      projection_type = optional(string, "ALL")
    })), [])
    local_secondary_indexes = optional(list(object({
      name            = string
      range_key       = string
      projection_type = optional(string, "ALL")
    })), [])
    ttl = optional(object({
      attribute_name = string
      enabled        = bool
    }))
    point_in_time_recovery_enabled = optional(bool, false)
    server_side_encryption_enabled = optional(bool, false)
  }))
  default = {}
}