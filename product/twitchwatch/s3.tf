module "s3_bucket" {
  source = "../../modules/aws/s3"
  s3_bucket = {
    twitch-api-data-storage = {
      s3_bucket_name = "twitch-api-data-storage"
      lifecycle_rules = [
        {
          id     = "2month_delete"
          prefix = "/"
          transitions = [
            {
              days          = 31
              storage_class = "STANDARD_IA"
            }
          ]
          expiration = {
            days = 32
          }
        }
      ]
    }
  }
}