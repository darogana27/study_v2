module "s3_bucket" {
  source = "../modules/s3"
  s3_bucket = {
    amount-of-electricity = {
      s3_bucket_name = "amount-of-electricity"
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