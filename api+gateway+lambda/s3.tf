module "s3" {
  source         = "../modules/s3"
  s3_bucket_name = "lambda-package-20240218"
}