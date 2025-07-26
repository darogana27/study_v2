module "apigateway" {
  source = "../../modules/aws/apigateway"

  product         = "{{PRODUCT_NAME}}"
  rest_apis       = var.rest_apis
  http_apis       = var.http_apis
}

variable "rest_apis" {
  description = "REST API Gateway configuration"
  type = map(object({
    name        = string
    description = optional(string, "")
    deployment = optional(object({
      stage_name = string
    }))
  }))
  default = {}
}

variable "http_apis" {
  description = "HTTP API Gateway configuration"
  type = map(object({
    name        = string
    description = optional(string, "")
    stage = optional(object({
      name = string
    }))
  }))
  default = {}
}