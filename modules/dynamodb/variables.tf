variable "dynamodbs" {
  description = "DynamoDBの作成"
  type = map(object({
    name                   = string
    billing_mode           = string
    hash_key               = string
    range_key              = optional(string)
    read_capacity          = optional(number)
    write_capacity         = optional(number)
    hash_key_type          = string
    attributes             = list(object({
      name = string
      type = string
    }))
    global_secondary_indexes = optional(list(object({
      name               = string
      hash_key           = string
      range_key          = optional(string)
      read_capacity      = optional(number)
      write_capacity     = optional(number)
      projection_type    = string
      non_key_attributes = optional(list(string))
    })))
    ttl = optional(object({
      attribute_name = string
      enabled        = bool
    }))
  }))
}
