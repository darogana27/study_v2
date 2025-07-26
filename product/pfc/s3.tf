module "pfc_s3_bucket" {
  source = "../../modules/aws/s3"

  product = local.env.product

  s3_bucket = {
    temp-bucket = {
      s3_bucket_name          = "temp-bucket"
      force_destroy           = false
      versioning_status       = "Suspended"
      encryption_algorithm    = "AES256"
      block_public_acls       = false
      block_public_policy     = false
      ignore_public_acls      = false
      restrict_public_buckets = false

      lifecycle_rules = [
        {
          id      = "transition_rule"
          enabled = true
          transitions = [
            {
              days          = 30
              storage_class = "STANDARD_IA"
            },
            {
              days          = 90
              storage_class = "GLACIER"
            }
          ]
        }
      ]
    }
  }
}