output "cloudfront_oac_ids" {
  description = "CloudFront Origin Access Control のID"
  value       = { for k, v in aws_cloudfront_origin_access_control.it : k => v.id }
}

output "cloudfront_oac_etags" {
  description = "CloudFront Origin Access Control のETag"
  value       = { for k, v in aws_cloudfront_origin_access_control.it : k => v.etag }
}