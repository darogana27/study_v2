output "s3_bucket_id" {
  description = "S3バケットのID"
  value       = module.s3.s3_ids["qr_generator_bucket"]
}

output "s3_bucket_arn" {
  description = "S3バケットのARN"
  value       = module.s3.s3_arns["qr_generator_bucket"]
}

output "s3_bucket_name" {
  description = "S3バケット名"
  value       = "${local.project_name}-${local.environment}-bucket"
}