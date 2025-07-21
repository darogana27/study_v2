module "pfc_apigateway" {
  source = "../../modules/aws/apigateway"

  product         = "pfc"
  apigateway_type = "HTTP"

  http_apis = {
    main = {
      name        = "main-api"
      description = "PFC Main HTTP API Gateway"
      version     = "1.0"

      cors_configuration = {
        allow_credentials = false
        allow_headers     = ["content-type", "authorization", "x-api-key", "x-amz-date", "x-amz-security-token"]
        allow_methods     = ["GET", "POST", "PUT", "DELETE", "OPTIONS", "PATCH"]
        allow_origins     = ["*"]
        expose_headers    = []
        max_age           = 300
      }

      routes = {
        get_users = {
          route_key          = "GET /users"
          authorization_type = "NONE"
          operation_name     = "GetUsers"
        }
        post_users = {
          route_key          = "POST /users"
          authorization_type = "NONE"
          operation_name     = "CreateUser"
        }
        get_user_by_id = {
          route_key          = "GET /users/{id}"
          authorization_type = "NONE"
          operation_name     = "GetUserById"
        }
        put_user = {
          route_key          = "PUT /users/{id}"
          authorization_type = "NONE"
          operation_name     = "UpdateUser"
        }
        delete_user = {
          route_key          = "DELETE /users/{id}"
          authorization_type = "NONE"
          operation_name     = "DeleteUser"
        }
        get_parking = {
          route_key          = "GET /parking"
          authorization_type = "NONE"
          operation_name     = "GetParkingInfo"
        }
        post_parking_search = {
          route_key          = "POST /parking/search"
          authorization_type = "NONE"
          operation_name     = "SearchParking"
        }
        get_chat = {
          route_key          = "GET /chat"
          authorization_type = "NONE"
          operation_name     = "GetChatHistory"
        }
        post_chat = {
          route_key          = "POST /chat"
          authorization_type = "NONE"
          operation_name     = "SendChatMessage"
        }
      }

      integrations = {
        get_users = {
          route_key              = "GET /users"
          integration_type       = "AWS_PROXY"
          integration_uri        = module.lambda_functions.arns["park-finder-chat"]
          integration_method     = "POST"
          payload_format_version = "2.0"
          timeout_milliseconds   = 30000
        }
        post_users = {
          route_key              = "POST /users"
          integration_type       = "AWS_PROXY"
          integration_uri        = module.lambda_functions.arns["park-finder-chat"]
          integration_method     = "POST"
          payload_format_version = "2.0"
          timeout_milliseconds   = 30000
        }
        get_user_by_id = {
          route_key              = "GET /users/{id}"
          integration_type       = "AWS_PROXY"
          integration_uri        = module.lambda_functions.arns["park-finder-chat"]
          integration_method     = "POST"
          payload_format_version = "2.0"
          timeout_milliseconds   = 30000
        }
        put_user = {
          route_key              = "PUT /users/{id}"
          integration_type       = "AWS_PROXY"
          integration_uri        = module.lambda_functions.arns["park-finder-chat"]
          integration_method     = "POST"
          payload_format_version = "2.0"
          timeout_milliseconds   = 30000
        }
        delete_user = {
          route_key              = "DELETE /users/{id}"
          integration_type       = "AWS_PROXY"
          integration_uri        = module.lambda_functions.arns["park-finder-chat"]
          integration_method     = "POST"
          payload_format_version = "2.0"
          timeout_milliseconds   = 30000
        }
        get_parking = {
          route_key              = "GET /parking"
          integration_type       = "AWS_PROXY"
          integration_uri        = module.lambda_functions.arns["park-finder-chat"]
          integration_method     = "POST"
          payload_format_version = "2.0"
          timeout_milliseconds   = 30000
        }
        post_parking_search = {
          route_key              = "POST /parking/search"
          integration_type       = "AWS_PROXY"
          integration_uri        = module.lambda_functions.arns["park-finder-chat"]
          integration_method     = "POST"
          payload_format_version = "2.0"
          timeout_milliseconds   = 30000
        }
        get_chat = {
          route_key              = "GET /chat"
          integration_type       = "AWS_PROXY"
          integration_uri        = module.lambda_functions.arns["park-finder-chat"]
          integration_method     = "POST"
          payload_format_version = "2.0"
          timeout_milliseconds   = 30000
        }
        post_chat = {
          route_key              = "POST /chat"
          integration_type       = "AWS_PROXY"
          integration_uri        = module.lambda_functions.arns["park-finder-chat"]
          integration_method     = "POST"
          payload_format_version = "2.0"
          timeout_milliseconds   = 30000
        }
      }

      stage = {
        name        = "prod"
        description = "Production stage for PFC API"
        auto_deploy = true
        variables = {
          environment = "production"
        }
      }

      tags = {
        Name        = "pfc-http-api"
        Environment = "production"
        Service     = "pfc"
        Type        = "api-gateway"
      }
    }
  }
}

# Lambda permission for API Gateway to invoke the function
resource "aws_lambda_permission" "apigateway_invoke" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = "pfc-park-finder-chat-function"
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${module.pfc_apigateway.http_api_execution_arn["main"]}/*/*"
}