variable "s3_bucket" {
  description = "s3バケットの定義を設定します"
  type = map(object({
    s3_bucket_name           = string
    force_destroy            = optional(bool, true)
    object_lock_enabled      = optional(bool, false)
    accelerate_configuration = optional(string, "Suspended")
    bucket_acl               = optional(string, "private")
    object_ownership         = optional(string, "BucketOwnerPreferred") 
    versioning_status        = optional(string, "Enabled")
    encryption_algorithm     = optional(string, "AES256")
    block_public_acls        = optional(bool, true)
    block_public_policy      = optional(bool, true)
    ignore_public_acls       = optional(bool, true)
    restrict_public_buckets  = optional(bool, true)
    lifecycle_rules = optional(list(object({
      id      = string
      prefix  = optional(string)
      enabled = optional(bool, true)
      transitions = optional(list(object({
        days          = number
        storage_class = string
      })))
      expiration = optional(object({
        days = optional(number)
      }))
    })), [])
    notifications = optional(list(object({
      event_type   = string
      filter_prefix = optional(string)
      filter_suffix = optional(string)
      lambda_function_arn = optional(string)
      topic_arn          = optional(string)
      queue_arn          = optional(string)
    })), [])
  }))
}