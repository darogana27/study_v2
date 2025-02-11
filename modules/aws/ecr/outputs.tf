output "repository_urls" {
  description = "Map of repository names to repository URLs"
  value = {
    for k, v in aws_ecr_repository.it : k => v.repository_url
  }
}

output "repository_arns" {
  description = "Map of repository names to repository ARNs"
  value = {
    for k, v in aws_ecr_repository.it : k => v.arn
  }
}