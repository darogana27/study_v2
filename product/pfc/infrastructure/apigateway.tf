module "pfc_apigateway" {
  source = "../../../modules/aws/apigateway"

  product         = local.env.product
  apigateway_type = "HTTP"

  http_apis = {
    main = {
      name        = "${local.env.product}-main-api"
      description = "${local.env.product} Main HTTP API Gateway"

      cors_configuration = {
        allow_credentials = false
        allow_headers     = ["content-type"]
        allow_methods     = ["GET", "POST", "OPTIONS"]
        allow_origins     = ["*"]
        expose_headers    = ["content-length"]
        max_age           = 300
      }

      routes = {
        post_chat = {
          route_key          = "POST /chat"
          authorization_type = "NONE"
          operation_name     = "PostChat"
        }
      }

      integrations = {
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
        name        = "dev"
        description = "dev stage for ${local.env.product} API"
        auto_deploy = true
        variables   = null
      }

    }
  }
}

# Lambda permission for API Gateway to invoke the function
resource "aws_lambda_permission" "apigateway_invoke" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = "${local.env.product}-park-finder-chat-function"
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${module.pfc_apigateway.http_api_execution_arn["main"]}/*/*"
}