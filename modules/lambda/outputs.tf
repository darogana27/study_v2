output "arns" {
  value = { for k, v in aws_lambda_function.it : k => v.arn }
  description = "各Lambda関数のARN"
}