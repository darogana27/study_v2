# REST API Gateway Resources
resource "aws_api_gateway_rest_api" "it" {
  for_each = var.apigateway_type == "REST" ? var.rest_apis : {}

  name                         = "${var.product}-${each.value.name}"
  description                  = each.value.description
  api_key_source              = each.value.api_key_source
  binary_media_types          = each.value.binary_media_types
  disable_execute_api_endpoint = each.value.disable_execute_api_endpoint
  policy                      = each.value.policy

  endpoint_configuration {
    types            = each.value.endpoint_configuration.types
    vpc_endpoint_ids = each.value.endpoint_configuration.vpc_endpoint_ids
  }

  tags = merge(each.value.tags, {
    Name    = "${var.product}-${each.value.name}"
    product = var.product
  })
}

# REST API Resources
resource "aws_api_gateway_resource" "it" {
  for_each = {
    for k, v in flatten([
      for api_key, api in var.rest_apis : [
        for res_key, resource in api.resources : {
          key         = "${api_key}-${res_key}"
          api_key     = api_key
          resource_key = res_key
          path_part   = resource.path_part
          parent_path = resource.parent_path
        }
      ]
    ]) : v.key => v if var.apigateway_type == "REST"
  }

  rest_api_id = aws_api_gateway_rest_api.it[each.value.api_key].id
  parent_id   = each.value.parent_path == "/" ? aws_api_gateway_rest_api.it[each.value.api_key].root_resource_id : aws_api_gateway_resource.it["${each.value.api_key}-${each.value.parent_path}"].id
  path_part   = each.value.path_part
}

# REST API Methods
resource "aws_api_gateway_method" "it" {
  for_each = {
    for k, v in flatten([
      for api_key, api in var.rest_apis : [
        for method_key, method in api.methods : {
          key                  = "${api_key}-${method_key}"
          api_key             = api_key
          method_key          = method_key
          resource_path       = method.resource_path
          http_method         = method.http_method
          authorization       = method.authorization
          authorizer_id       = method.authorizer_id
          api_key_required    = method.api_key_required
          request_models      = method.request_models
          request_validator_id = method.request_validator_id
          request_parameters  = method.request_parameters
        }
      ]
    ]) : v.key => v if var.apigateway_type == "REST"
  }

  rest_api_id   = aws_api_gateway_rest_api.it[each.value.api_key].id
  resource_id   = each.value.resource_path == "/" ? aws_api_gateway_rest_api.it[each.value.api_key].root_resource_id : aws_api_gateway_resource.it["${each.value.api_key}-${each.value.resource_path}"].id
  http_method   = each.value.http_method
  authorization = each.value.authorization
  authorizer_id = each.value.authorizer_id
  api_key_required = each.value.api_key_required
  request_models = each.value.request_models
  request_validator_id = each.value.request_validator_id
  request_parameters = each.value.request_parameters
}

# REST API Integrations
resource "aws_api_gateway_integration" "it" {
  for_each = {
    for k, v in flatten([
      for api_key, api in var.rest_apis : [
        for int_key, integration in api.integrations : {
          key                     = "${api_key}-${int_key}"
          api_key                = api_key
          integration_key        = int_key
          resource_path          = integration.resource_path
          http_method            = integration.http_method
          integration_http_method = integration.integration_http_method
          type                   = integration.type
          connection_type        = integration.connection_type
          connection_id          = integration.connection_id
          uri                    = integration.uri
          credentials            = integration.credentials
          request_templates      = integration.request_templates
          request_parameters     = integration.request_parameters
          passthrough_behavior   = integration.passthrough_behavior
          cache_key_parameters   = integration.cache_key_parameters
          cache_namespace        = integration.cache_namespace
          content_handling       = integration.content_handling
          timeout_milliseconds   = integration.timeout_milliseconds
        }
      ]
    ]) : v.key => v if var.apigateway_type == "REST"
  }

  rest_api_id = aws_api_gateway_rest_api.it[each.value.api_key].id
  resource_id = each.value.resource_path == "/" ? aws_api_gateway_rest_api.it[each.value.api_key].root_resource_id : aws_api_gateway_resource.it["${each.value.api_key}-${each.value.resource_path}"].id
  http_method = aws_api_gateway_method.it["${each.value.api_key}-${each.value.integration_key}"].http_method

  integration_http_method = each.value.integration_http_method
  type                   = each.value.type
  connection_type        = each.value.connection_type
  connection_id          = each.value.connection_id
  uri                    = each.value.uri
  credentials            = each.value.credentials
  request_templates      = each.value.request_templates
  request_parameters     = each.value.request_parameters
  passthrough_behavior   = each.value.passthrough_behavior
  cache_key_parameters   = each.value.cache_key_parameters
  cache_namespace        = each.value.cache_namespace
  content_handling       = each.value.content_handling
  timeout_milliseconds   = each.value.timeout_milliseconds
}

# REST API Deployment
resource "aws_api_gateway_deployment" "it" {
  for_each = {
    for api_key, api in var.rest_apis : api_key => api
    if var.apigateway_type == "REST" && api.deployment != null
  }

  rest_api_id = aws_api_gateway_rest_api.it[each.key].id
  description = each.value.deployment.description

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_rest_api.it[each.key],
      aws_api_gateway_resource.it,
      aws_api_gateway_method.it,
      aws_api_gateway_integration.it,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_method.it,
    aws_api_gateway_integration.it,
  ]
}

# REST API Stage
resource "aws_api_gateway_stage" "it" {
  for_each = {
    for api_key, api in var.rest_apis : api_key => api
    if var.apigateway_type == "REST" && api.deployment != null
  }

  deployment_id = aws_api_gateway_deployment.it[each.key].id
  rest_api_id   = aws_api_gateway_rest_api.it[each.key].id
  stage_name    = each.value.deployment.stage_name
  description   = each.value.deployment.stage_description
  variables     = each.value.deployment.variables

  tags = {
    Name    = "${var.product}-${each.value.name}-${each.value.deployment.stage_name}"
    product = var.product
  }
}

# HTTP API Gateway Resources
resource "aws_apigatewayv2_api" "it" {
  for_each = var.apigateway_type == "HTTP" ? var.http_apis : {}

  name                         = "${var.product}-${each.value.name}"
  description                  = each.value.description
  protocol_type               = each.value.protocol_type
  version                     = each.value.version
  api_key_selection_expression = each.value.api_key_selection_expression
  route_key                   = each.value.route_key
  route_selection_expression  = each.value.route_selection_expression
  disable_execute_api_endpoint = each.value.disable_execute_api_endpoint

  dynamic "cors_configuration" {
    for_each = each.value.cors_configuration != null ? [each.value.cors_configuration] : []
    content {
      allow_credentials = cors_configuration.value.allow_credentials
      allow_headers     = cors_configuration.value.allow_headers
      allow_methods     = cors_configuration.value.allow_methods
      allow_origins     = cors_configuration.value.allow_origins
      expose_headers    = cors_configuration.value.expose_headers
      max_age           = cors_configuration.value.max_age
    }
  }

  tags = merge(each.value.tags, {
    Name    = "${var.product}-${each.value.name}"
    product = var.product
  })
}

# HTTP API Routes
resource "aws_apigatewayv2_route" "it" {
  for_each = {
    for k, v in flatten([
      for api_key, api in var.http_apis : [
        for route_key, route in api.routes : {
          key                                  = "${api_key}-${route_key}"
          api_key                             = api_key
          route_key_val                       = route.route_key
          authorization_type                  = route.authorization_type
          authorizer_id                       = route.authorizer_id
          api_key_required                    = route.api_key_required
          operation_name                      = route.operation_name
          request_models                      = route.request_models
          request_parameter                   = route.request_parameter
          route_response_selection_expression = route.route_response_selection_expression
        }
      ]
    ]) : v.key => v if var.apigateway_type == "HTTP"
  }

  api_id    = aws_apigatewayv2_api.it[each.value.api_key].id
  route_key = each.value.route_key_val
  authorization_type = each.value.authorization_type
  authorizer_id = each.value.authorizer_id
  api_key_required = each.value.api_key_required
  operation_name = each.value.operation_name
  request_models = each.value.request_models
  route_response_selection_expression = each.value.route_response_selection_expression

  dynamic "request_parameter" {
    for_each = each.value.request_parameter
    content {
      location = request_parameter.value.location
      required = request_parameter.value.required
    }
  }
}

# HTTP API Integrations
resource "aws_apigatewayv2_integration" "it" {
  for_each = {
    for k, v in flatten([
      for api_key, api in var.http_apis : [
        for int_key, integration in api.integrations : {
          key                           = "${api_key}-${int_key}"
          api_key                       = api_key
          route_key                     = integration.route_key
          integration_type              = integration.integration_type
          connection_type               = integration.connection_type
          connection_id                 = integration.connection_id
          content_handling_strategy     = integration.content_handling_strategy
          credentials_arn               = integration.credentials_arn
          description                   = integration.description
          integration_method            = integration.integration_method
          integration_uri               = integration.integration_uri
          passthrough_behavior          = integration.passthrough_behavior
          payload_format_version        = integration.payload_format_version
          request_parameters            = integration.request_parameters
          request_templates             = integration.request_templates
          response_parameters           = integration.response_parameters
          template_selection_expression = integration.template_selection_expression
          timeout_milliseconds          = integration.timeout_milliseconds
        }
      ]
    ]) : v.key => v if var.apigateway_type == "HTTP"
  }

  api_id                    = aws_apigatewayv2_api.it[each.value.api_key].id
  integration_type          = each.value.integration_type
  connection_type           = each.value.connection_type
  connection_id             = each.value.connection_id
  content_handling_strategy = each.value.content_handling_strategy
  credentials_arn           = each.value.credentials_arn
  description               = each.value.description
  integration_method        = each.value.integration_method
  integration_uri           = each.value.integration_uri
  passthrough_behavior      = each.value.passthrough_behavior
  payload_format_version    = each.value.payload_format_version
  request_parameters        = each.value.request_parameters
  request_templates         = each.value.request_templates
  response_parameters       = each.value.response_parameters
  template_selection_expression = each.value.template_selection_expression
  timeout_milliseconds      = each.value.timeout_milliseconds
}

# HTTP API Route Integration
resource "aws_apigatewayv2_route" "integration" {
  for_each = {
    for k, v in flatten([
      for api_key, api in var.http_apis : [
        for int_key, integration in api.integrations : {
          key         = "${api_key}-${int_key}-integration"
          api_key     = api_key
          route_key   = integration.route_key
          int_key     = int_key
        }
      ]
    ]) : v.key => v if var.apigateway_type == "HTTP"
  }

  api_id    = aws_apigatewayv2_api.it[each.value.api_key].id
  route_key = each.value.route_key
  target    = "integrations/${aws_apigatewayv2_integration.it["${each.value.api_key}-${each.value.int_key}"].id}"

  depends_on = [aws_apigatewayv2_integration.it]
}

# HTTP API Stage
resource "aws_apigatewayv2_stage" "it" {
  for_each = {
    for api_key, api in var.http_apis : api_key => api
    if var.apigateway_type == "HTTP" && api.stage != null
  }

  api_id      = aws_apigatewayv2_api.it[each.key].id
  name        = each.value.stage.name
  description = each.value.stage.description
  auto_deploy = each.value.stage.auto_deploy
  stage_variables = each.value.stage.variables

  dynamic "throttle_settings" {
    for_each = each.value.stage.throttle_settings != null ? [each.value.stage.throttle_settings] : []
    content {
      rate_limit  = throttle_settings.value.rate_limit
      burst_limit = throttle_settings.value.burst_limit
    }
  }

  dynamic "access_log_settings" {
    for_each = each.value.stage.access_log_settings != null ? [each.value.stage.access_log_settings] : []
    content {
      destination_arn = access_log_settings.value.destination_arn
      format          = access_log_settings.value.format
    }
  }

  tags = {
    Name    = "${var.product}-${each.value.name}-${each.value.stage.name}"
    product = var.product
  }

  depends_on = [aws_apigatewayv2_route.integration]
}