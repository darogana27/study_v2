# REST API Outputs
output "rest_api_id" {
  description = "REST API Gateway ID"
  value = {
    for k, v in aws_api_gateway_rest_api.it : k => v.id
  }
}

output "rest_api_arn" {
  description = "REST API Gateway ARN"
  value = {
    for k, v in aws_api_gateway_rest_api.it : k => v.arn
  }
}

output "rest_api_execution_arn" {
  description = "REST API Gateway execution ARN"
  value = {
    for k, v in aws_api_gateway_rest_api.it : k => v.execution_arn
  }
}

output "rest_api_root_resource_id" {
  description = "REST API Gateway root resource ID"
  value = {
    for k, v in aws_api_gateway_rest_api.it : k => v.root_resource_id
  }
}

output "rest_api_invoke_url" {
  description = "REST API Gateway invoke URL"
  value = {
    for k, v in aws_api_gateway_stage.it : k => "https://${aws_api_gateway_rest_api.it[k].id}.execute-api.${data.aws_region.current.name}.amazonaws.com/${v.stage_name}"
  }
}

# HTTP API Outputs
output "http_api_id" {
  description = "HTTP API Gateway ID"
  value = {
    for k, v in aws_apigatewayv2_api.it : k => v.id
  }
}

output "http_api_arn" {
  description = "HTTP API Gateway ARN"
  value = {
    for k, v in aws_apigatewayv2_api.it : k => v.arn
  }
}

output "http_api_execution_arn" {
  description = "HTTP API Gateway execution ARN"
  value = {
    for k, v in aws_apigatewayv2_api.it : k => v.execution_arn
  }
}

output "http_api_endpoint" {
  description = "HTTP API Gateway endpoint"
  value = {
    for k, v in aws_apigatewayv2_api.it : k => v.api_endpoint
  }
}

output "http_api_invoke_url" {
  description = "HTTP API Gateway invoke URL"
  value = {
    for k, v in aws_apigatewayv2_stage.it : k => "${aws_apigatewayv2_api.it[k].api_endpoint}/${v.name}"
  }
}

# Common data source
data "aws_region" "current" {}