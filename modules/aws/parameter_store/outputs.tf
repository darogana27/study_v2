output "parameter_arns" {
  description = "作成されたパラメーターのARNのマップ"
  value       = { for k, v in aws_ssm_parameter.this : k => v.arn }
}

output "parameter_names" {
  description = "作成されたパラメーターの名前のマップ"
  value       = { for k, v in aws_ssm_parameter.this : k => v.name }
}