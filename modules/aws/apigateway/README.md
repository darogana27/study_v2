# API Gateway Module

このモジュールは、AWS API Gateway（REST API および HTTP API）を作成するためのTerraformモジュールです。

## 機能

- REST API Gateway の作成と設定
- HTTP API Gateway の作成と設定
- リソース、メソッド、統合の設定
- ステージとデプロイメントの管理
- CORS設定のサポート（HTTP API）

## 使用方法

### REST API Gateway

```hcl
module "api_gateway" {
  source = "../../modules/aws/apigateway"
  
  product          = "example"
  apigateway_type  = "REST"
  
  rest_apis = {
    main = {
      name        = "main-api"
      description = "Main REST API"
      
      resources = {
        users = {
          path_part   = "users"
          parent_path = "/"
        }
      }
      
      methods = {
        get_users = {
          resource_path = "users"
          http_method   = "GET"
          authorization = "NONE"
        }
      }
      
      integrations = {
        get_users = {
          resource_path           = "users"
          http_method            = "GET"
          integration_http_method = "POST"
          type                   = "AWS_PROXY"
          uri                    = "arn:aws:apigateway:region:lambda:path/2015-03-31/functions/function-arn/invocations"
        }
      }
      
      deployment = {
        stage_name        = "prod"
        stage_description = "Production stage"
        description       = "Production deployment"
      }
    }
  }
}
```

### HTTP API Gateway

```hcl
module "api_gateway" {
  source = "../../modules/aws/apigateway"
  
  product          = "example"
  apigateway_type  = "HTTP"
  
  http_apis = {
    main = {
      name        = "main-api"
      description = "Main HTTP API"
      
      cors_configuration = {
        allow_credentials = false
        allow_headers     = ["content-type", "authorization"]
        allow_methods     = ["GET", "POST", "PUT", "DELETE"]
        allow_origins     = ["*"]
        max_age          = 300
      }
      
      routes = {
        get_users = {
          route_key          = "GET /users"
          authorization_type = "NONE"
        }
      }
      
      integrations = {
        get_users = {
          route_key           = "GET /users"
          integration_type    = "AWS_PROXY"
          integration_uri     = "arn:aws:apigateway:region:lambda:path/2015-03-31/functions/function-arn/invocations"
          integration_method  = "POST"
          payload_format_version = "2.0"
        }
      }
      
      stage = {
        name        = "prod"
        description = "Production stage"
        auto_deploy = true
      }
    }
  }
}
```

## Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| product | プロダクト名 | string | n/a | yes |
| apigateway_type | API Gatewayのタイプ（REST または HTTP） | string | "REST" | no |
| rest_apis | REST API Gatewayの設定 | map(object) | {} | no |
| http_apis | HTTP API Gatewayの設定 | map(object) | {} | no |

## Outputs

### REST API

| Name | Description |
|------|-------------|
| rest_api_id | REST API Gateway ID |
| rest_api_arn | REST API Gateway ARN |
| rest_api_execution_arn | REST API Gateway execution ARN |
| rest_api_root_resource_id | REST API Gateway root resource ID |
| rest_api_invoke_url | REST API Gateway invoke URL |

### HTTP API

| Name | Description |
|------|-------------|
| http_api_id | HTTP API Gateway ID |
| http_api_arn | HTTP API Gateway ARN |
| http_api_execution_arn | HTTP API Gateway execution ARN |
| http_api_endpoint | HTTP API Gateway endpoint |
| http_api_invoke_url | HTTP API Gateway invoke URL |