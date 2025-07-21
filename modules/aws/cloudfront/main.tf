resource "aws_cloudfront_distribution" "it" {
  for_each = var.cloudfront_distributions

  aliases         = each.value.aliases
  comment         = each.value.comment
  default_root_object = each.value.default_root_object
  enabled         = each.value.enabled
  is_ipv6_enabled = each.value.is_ipv6_enabled
  price_class     = each.value.price_class
  retain_on_delete = each.value.retain_on_delete
  wait_for_deployment = each.value.wait_for_deployment

  dynamic "origin" {
    for_each = each.value.origins
    content {
      domain_name              = origin.value.domain_name
      origin_id                = origin.value.origin_id
      origin_access_control_id = origin.value.origin_access_control_id
      origin_path              = origin.value.origin_path

      dynamic "s3_origin_config" {
        for_each = origin.value.s3_origin_config != null ? [origin.value.s3_origin_config] : []
        content {
          origin_access_identity = s3_origin_config.value.origin_access_identity
        }
      }

      dynamic "custom_origin_config" {
        for_each = origin.value.custom_origin_config != null ? [origin.value.custom_origin_config] : []
        content {
          http_port              = custom_origin_config.value.http_port
          https_port             = custom_origin_config.value.https_port
          origin_protocol_policy = custom_origin_config.value.origin_protocol_policy
          origin_ssl_protocols   = custom_origin_config.value.origin_ssl_protocols
        }
      }
    }
  }

  default_cache_behavior {
    allowed_methods  = each.value.default_cache_behavior.allowed_methods
    cached_methods   = each.value.default_cache_behavior.cached_methods
    target_origin_id = each.value.default_cache_behavior.target_origin_id

    forwarded_values {
      query_string = each.value.default_cache_behavior.forwarded_values.query_string
      headers      = each.value.default_cache_behavior.forwarded_values.headers

      cookies {
        forward           = each.value.default_cache_behavior.forwarded_values.cookies.forward
        whitelisted_names = each.value.default_cache_behavior.forwarded_values.cookies.whitelisted_names
      }
    }

    viewer_protocol_policy = each.value.default_cache_behavior.viewer_protocol_policy
    min_ttl                = each.value.default_cache_behavior.min_ttl
    default_ttl            = each.value.default_cache_behavior.default_ttl
    max_ttl                = each.value.default_cache_behavior.max_ttl
    compress               = each.value.default_cache_behavior.compress
  }

  dynamic "ordered_cache_behavior" {
    for_each = each.value.ordered_cache_behaviors != null ? each.value.ordered_cache_behaviors : []
    content {
      path_pattern     = ordered_cache_behavior.value.path_pattern
      allowed_methods  = ordered_cache_behavior.value.allowed_methods
      cached_methods   = ordered_cache_behavior.value.cached_methods
      target_origin_id = ordered_cache_behavior.value.target_origin_id

      forwarded_values {
        query_string = ordered_cache_behavior.value.forwarded_values.query_string
        headers      = ordered_cache_behavior.value.forwarded_values.headers

        cookies {
          forward           = ordered_cache_behavior.value.forwarded_values.cookies.forward
          whitelisted_names = ordered_cache_behavior.value.forwarded_values.cookies.whitelisted_names
        }
      }

      viewer_protocol_policy = ordered_cache_behavior.value.viewer_protocol_policy
      min_ttl                = ordered_cache_behavior.value.min_ttl
      default_ttl            = ordered_cache_behavior.value.default_ttl
      max_ttl                = ordered_cache_behavior.value.max_ttl
      compress               = ordered_cache_behavior.value.compress
    }
  }

  dynamic "custom_error_response" {
    for_each = each.value.custom_error_responses != null ? each.value.custom_error_responses : []
    content {
      error_code         = custom_error_response.value.error_code
      response_code      = custom_error_response.value.response_code
      response_page_path = custom_error_response.value.response_page_path
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = each.value.restrictions.geo_restriction.restriction_type
      locations        = each.value.restrictions.geo_restriction.locations
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = each.value.viewer_certificate.cloudfront_default_certificate
    acm_certificate_arn            = each.value.viewer_certificate.acm_certificate_arn
    ssl_support_method             = each.value.viewer_certificate.ssl_support_method
    minimum_protocol_version       = each.value.viewer_certificate.minimum_protocol_version
  }

  dynamic "logging_config" {
    for_each = each.value.logging_config != null ? [each.value.logging_config] : []
    content {
      include_cookies = logging_config.value.include_cookies
      bucket          = logging_config.value.bucket
      prefix          = logging_config.value.prefix
    }
  }

  tags = each.value.tags
}

resource "aws_cloudfront_origin_access_control" "it" {
  for_each = var.cloudfront_oac

  name                              = each.value.name
  description                       = each.value.description
  origin_access_control_origin_type = each.value.origin_access_control_origin_type
  signing_behavior                  = each.value.signing_behavior
  signing_protocol                  = each.value.signing_protocol
}