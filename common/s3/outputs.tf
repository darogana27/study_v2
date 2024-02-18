output "s3_bucket_arn" {
  value = module.apilambda_s3.s3_id
  description = "The ARN of the S3 bucket"
}