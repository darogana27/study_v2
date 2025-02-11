variable "product" {
  description = "product名"
  type        = string
}

variable "dynamodbs" {
  description = "DynamoDBの作成"
  type = map(object({
    billing_mode   = string
    hash_key       = string
    range_key      = optional(string)
    read_capacity  = optional(number)
    write_capacity = optional(number)
    hash_key_type  = string
    attributes = list(object({
      name = string
      type = string
    }))
    global_secondary_indexes = optional(list(object({
      hash_key           = string
      range_key          = optional(string)
      projection_type    = string
      non_key_attributes = optional(list(string))
      read_capacity      = optional(number)
      write_capacity     = optional(number)
    })))
    ttl = optional(object({
      attribute_name = string
      enabled        = bool
    }))
  }))
}
