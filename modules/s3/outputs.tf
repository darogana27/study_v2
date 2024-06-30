output "s3_ids" {
  value = { for k, v in aws_s3_bucket.it : k => v.id }
}

output "s3_arns" {
  value = { for k, v in aws_s3_bucket.it : k => v.arn }
}