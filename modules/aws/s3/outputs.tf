output "s3_ids" {
  value = { for k, v in aws_s3_bucket.it : k => v.id }
}

output "s3_arns" {
  value = { for k, v in aws_s3_bucket.it : k => v.arn }
}

output "s3_bucket_domain_name" {
  value = { for k, v in aws_s3_bucket.it : k => v.bucket_domain_name }
}

output "s3_bucket_regional_domain_name" {
  value = { for k, v in aws_s3_bucket.it : k => v.bucket_regional_domain_name }
}