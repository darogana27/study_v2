module "s3" {
  source = "../../modules/aws/s3"

  product   = "{{PRODUCT_NAME}}"
  s3_bucket = var.s3_bucket
}

variable "s3_bucket" {
  description = "S3 buckets configuration"
  type = map(object({
    s3_bucket_name   = string
    force_destroy    = optional(bool, false)
    acceleration     = optional(string, "Suspended")
    versioning       = optional(bool, false)
    lifecycle_rules  = optional(map(object({
      id              = string
      enabled         = optional(bool, true)
      expiration_days = optional(number)
      transitions = optional(list(object({
        days          = number
        storage_class = string
      })), [])
    })), {})
    notifications = optional(map(object({
      events            = list(string)
      lambda_function   = optional(string)
      topic             = optional(string)
      queue             = optional(string)
      filter_prefix     = optional(string, "")
      filter_suffix     = optional(string, "")
    })), {})
  }))
  default = {}
}