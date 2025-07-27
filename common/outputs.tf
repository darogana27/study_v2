# Backend module outputs
output "backend_bucket_name" {
  description = "Name of the S3 bucket for Terraform state"
  value       = module.backend.s3_bucket_name
}

output "backend_bucket_arn" {
  description = "ARN of the S3 bucket for Terraform state"
  value       = module.backend.s3_bucket_arn
}