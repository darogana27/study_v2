output "cloudfront_distribution_ids" {
  description = "CloudFrontディストリビューションのID"
  value       = { for k, v in aws_cloudfront_distribution.it : k => v.id }
}

output "cloudfront_distribution_arns" {
  description = "CloudFrontディストリビューションのARN"
  value       = { for k, v in aws_cloudfront_distribution.it : k => v.arn }
}

output "cloudfront_distribution_domain_names" {
  description = "CloudFrontディストリビューションのドメイン名"
  value       = { for k, v in aws_cloudfront_distribution.it : k => v.domain_name }
}

output "cloudfront_distribution_hosted_zone_ids" {
  description = "CloudFrontディストリビューションのホストゾーンID"
  value       = { for k, v in aws_cloudfront_distribution.it : k => v.hosted_zone_id }
}

output "cloudfront_oac_ids" {
  description = "CloudFront Origin Access Control のID"
  value       = { for k, v in aws_cloudfront_origin_access_control.it : k => v.id }
}

output "cloudfront_oac_id" {
  description = "CloudFront Origin Access Control のID (単数形)"
  value       = { for k, v in aws_cloudfront_origin_access_control.it : k => v.id }
}

output "cloudfront_distribution_arn" {
  description = "CloudFrontディストリビューションのARN (単数形)"
  value       = { for k, v in aws_cloudfront_distribution.it : k => v.arn }
}

output "cloudfront_oac_etags" {
  description = "CloudFront Origin Access Control のETag"
  value       = { for k, v in aws_cloudfront_origin_access_control.it : k => v.etag }
}