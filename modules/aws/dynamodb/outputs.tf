output "dynamodb_table_names" {
  description = "DynamoDBテーブル名"
  value       = { for k, v in aws_dynamodb_table.it : k => v.name }
}

output "dynamodb_table_arns" {
  description = "DynamoDBテーブルARN"
  value       = { for k, v in aws_dynamodb_table.it : k => v.arn }
}

output "dynamodb_table_ids" {
  description = "DynamoDBテーブルID"
  value       = { for k, v in aws_dynamodb_table.it : k => v.id }
}