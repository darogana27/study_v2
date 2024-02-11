module "s3_bucket_upload" {
  source         = "../../modules/s3"
  s3_bucket_name = local.s3_bucket_upload
}

module "s3_bucket_transcoded" {
  source         = "../../modules/s3"
  s3_bucket_name = local.s3_bucket_transcoded
}