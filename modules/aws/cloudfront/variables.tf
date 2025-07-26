variable "product" {
  description = "product名"
  type        = string
}

variable "environment" {
  description = "環境名"
  type        = string
  default     = null
}

variable "cloudfront_distributions" {
  description = "CloudFrontディストリビューションの設定を定義します"
  type = map(object({
    aliases             = optional(list(string), [])
    comment             = optional(string, "Managed by Terraform")
    default_root_object = optional(string, "index.html")
    enabled             = optional(bool, true)
    is_ipv6_enabled     = optional(bool, true)
    price_class         = optional(string, "PriceClass_All")
    retain_on_delete    = optional(bool, false)
    wait_for_deployment = optional(bool, true)

    origins = list(object({
      domain_name              = string
      origin_id                = string
      origin_access_control_id = optional(string)
      origin_path              = optional(string)

      s3_origin_config = optional(object({
        origin_access_identity = string
      }))

      custom_origin_config = optional(object({
        http_port              = optional(number, 80)
        https_port             = optional(number, 443)
        origin_protocol_policy = optional(string, "match-viewer")
        origin_ssl_protocols   = optional(list(string), ["TLSv1.2"])
      }))
    }))

    default_cache_behavior = object({
      allowed_methods  = optional(list(string), ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"])
      cached_methods   = optional(list(string), ["GET", "HEAD"])
      target_origin_id = string

      forwarded_values = object({
        query_string = optional(bool, false)
        headers      = optional(list(string), [])

        cookies = object({
          forward           = optional(string, "none")
          whitelisted_names = optional(list(string), [])
        })
      })

      viewer_protocol_policy = optional(string, "redirect-to-https")
      min_ttl                = optional(number, 0)
      default_ttl            = optional(number, 3600)
      max_ttl                = optional(number, 86400)
      compress               = optional(bool, true)
    })

    ordered_cache_behaviors = optional(list(object({
      path_pattern     = string
      allowed_methods  = optional(list(string), ["GET", "HEAD", "OPTIONS"])
      cached_methods   = optional(list(string), ["GET", "HEAD"])
      target_origin_id = string

      forwarded_values = object({
        query_string = optional(bool, false)
        headers      = optional(list(string), [])

        cookies = object({
          forward           = optional(string, "none")
          whitelisted_names = optional(list(string), [])
        })
      })

      viewer_protocol_policy = optional(string, "redirect-to-https")
      min_ttl                = optional(number, 0)
      default_ttl            = optional(number, 3600)
      max_ttl                = optional(number, 86400)
      compress               = optional(bool, true)
    })))

    custom_error_responses = optional(list(object({
      error_code         = number
      response_code      = optional(number)
      response_page_path = optional(string)
    })))

    restrictions = object({
      geo_restriction = object({
        restriction_type = optional(string, "none")
        locations        = optional(list(string), [])
      })
    })

    viewer_certificate = object({
      cloudfront_default_certificate = optional(bool, true)
      acm_certificate_arn            = optional(string)
      ssl_support_method             = optional(string, "sni-only")
      minimum_protocol_version       = optional(string, "TLSv1.2_2021")
    })

    logging_config = optional(object({
      include_cookies = optional(bool, false)
      bucket          = string
      prefix          = optional(string, "")
    }))

    tags = optional(map(string), {})
  }))
  default = {}
}

variable "cloudfront_oac" {
  description = "CloudFront Origin Access Control の設定を定義します"
  type = map(object({
    name                              = string
    description                       = optional(string, "Origin Access Control for S3")
    origin_access_control_origin_type = optional(string, "s3")
    signing_behavior                  = optional(string, "always")
    signing_protocol                  = optional(string, "sigv4")
  }))
  default = {}
}