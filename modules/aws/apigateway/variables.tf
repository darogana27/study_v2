variable "product" {
  description = "product名"
  type        = string
}

variable "apigateway_type" {
  description = "API Gateway type: 'REST' or 'HTTP'"
  type        = string
  default     = "REST"
  validation {
    condition     = contains(["REST", "HTTP"], var.apigateway_type)
    error_message = "apigateway_type must be either 'REST' or 'HTTP'."
  }
}

variable "rest_apis" {
  description = "REST API Gatewayの設定をマップで定義します"
  type = map(object({
    name                         = string
    description                  = optional(string, "Managed by Terraform")
    api_key_source              = optional(string, "HEADER")
    binary_media_types          = optional(list(string), [])
    disable_execute_api_endpoint = optional(bool, false)
    endpoint_configuration = optional(object({
      types            = list(string)
      vpc_endpoint_ids = optional(list(string))
    }), {
      types = ["REGIONAL"]
    })
    policy = optional(string)
    tags   = optional(map(string), {})
    
    resources = optional(map(object({
      path_part   = string
      parent_path = optional(string, "/")
    })), {})
    
    methods = optional(map(object({
      resource_path      = string
      http_method       = string
      authorization     = optional(string, "NONE")
      authorizer_id     = optional(string)
      api_key_required  = optional(bool, false)
      request_models    = optional(map(string), {})
      request_validator_id = optional(string)
      request_parameters = optional(map(bool), {})
    })), {})
    
    integrations = optional(map(object({
      resource_path           = string
      http_method            = string
      integration_http_method = string
      type                   = string
      connection_type        = optional(string, "INTERNET")
      connection_id          = optional(string)
      uri                    = string
      credentials            = optional(string)
      request_templates      = optional(map(string), {})
      request_parameters     = optional(map(string), {})
      passthrough_behavior   = optional(string)
      cache_key_parameters   = optional(list(string), [])
      cache_namespace        = optional(string)
      content_handling       = optional(string)
      timeout_milliseconds   = optional(number, 29000)
    })), {})
    
    deployment = optional(object({
      stage_name        = string
      stage_description = optional(string)
      description       = optional(string)
      variables         = optional(map(string), {})
    }))
  }))
  default = {}
}

variable "http_apis" {
  description = "HTTP API Gatewayの設定をマップで定義します"
  type = map(object({
    name                         = string
    description                  = optional(string, "Managed by Terraform")
    protocol_type               = optional(string, "HTTP")
    version                     = optional(string, "1.0")
    api_key_selection_expression = optional(string)
    route_key                   = optional(string)
    route_selection_expression  = optional(string, "$request.method $request.path")
    disable_execute_api_endpoint = optional(bool, false)
    cors_configuration = optional(object({
      allow_credentials = optional(bool, false)
      allow_headers     = optional(list(string), [])
      allow_methods     = optional(list(string), [])
      allow_origins     = optional(list(string), [])
      expose_headers    = optional(list(string), [])
      max_age           = optional(number, 0)
    }))
    tags = optional(map(string), {})
    
    routes = optional(map(object({
      route_key          = string
      authorization_type = optional(string, "NONE")
      authorizer_id      = optional(string)
      api_key_required   = optional(bool, false)
      operation_name     = optional(string)
      request_models     = optional(map(string), {})
      request_parameter  = optional(map(object({
        location        = string
        required        = bool
      })), {})
      route_response_selection_expression = optional(string)
    })), {})
    
    integrations = optional(map(object({
      route_key                    = string
      integration_type             = string
      connection_type              = optional(string, "INTERNET")
      connection_id                = optional(string)
      content_handling_strategy    = optional(string)
      credentials_arn              = optional(string)
      description                  = optional(string)
      integration_method           = optional(string)
      integration_uri              = string
      passthrough_behavior         = optional(string)
      payload_format_version       = optional(string, "2.0")
      request_parameters           = optional(map(string), {})
      request_templates            = optional(map(string), {})
      response_parameters          = optional(map(map(string)), {})
      template_selection_expression = optional(string)
      timeout_milliseconds         = optional(number, 30000)
    })), {})
    
    stage = optional(object({
      name               = string
      description        = optional(string)
      deployment_id      = optional(string)
      variables          = optional(map(string), {})
      auto_deploy        = optional(bool, true)
      throttle_settings = optional(object({
        rate_limit  = optional(number)
        burst_limit = optional(number)
      }))
      access_log_settings = optional(object({
        destination_arn = string
        format         = optional(string)
      }))
    }))
  }))
  default = {}
}