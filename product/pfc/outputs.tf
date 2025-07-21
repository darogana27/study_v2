
# Outputs
output "s3_bucket_name" {
  value = module.pfc_s3_bucket.s3_ids["pfc-temp-bucket"]
}

output "api_endpoint" {
  value = module.pfc_apigateway.http_api_endpoint["main"]
}

output "cloudfront_url" {
  value = "https://${module.pfc_cloudfront.cloudfront_distribution_domain_names["main"]}"
}

output "dynamodb_table_name" {
  value = module.dynamodb.dynamodb_table_names["ParkingSpots"]
}