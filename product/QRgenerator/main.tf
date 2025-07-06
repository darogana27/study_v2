locals {
  project_name = "qr-generator"
  environment  = "dev"
}

module "s3" {
  source = "../../modules/aws/s3"

  s3_bucket = {
    qr_generator_bucket = {
      s3_bucket_name           = "${local.project_name}-${local.environment}"
      force_destroy            = true
      object_lock_enabled      = false
      accelerate_configuration = "Suspended"
      bucket_acl               = "private"
      object_ownership         = "BucketOwnerPreferred"
      versioning_status        = "Suspended"
      encryption_algorithm     = "AES256"
      block_public_acls        = true
      block_public_policy      = true
      ignore_public_acls       = true
      restrict_public_buckets  = true
      lifecycle_rules = [
        {
          id      = "delete_old_files"
          prefix  = "qr-codes/"
          enabled = true
          expiration = {
            days = 30
          }
        }
      ]
      notifications = []
    }
  }
}