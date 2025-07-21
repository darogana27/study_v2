module "pfc_cloudfront" {
  source = "../../modules/aws/cloudfront"

  cloudfront_oac = {
    main_oac = {
      name                              = "pfc-s3-oac"
      description                       = "OAC for PFC S3 bucket access"
      origin_access_control_origin_type = "s3"
      signing_behavior                  = "always"
      signing_protocol                  = "sigv4"
    }
  }

  cloudfront_distributions = {
    main = {
      comment             = "PFC CloudFront Distribution"
      default_root_object = "index.html"
      enabled             = true
      is_ipv6_enabled     = true
      price_class         = "PriceClass_100"
      wait_for_deployment = true

      origins = [
        {
          domain_name              = module.pfc_s3_bucket.s3_bucket_domain_name["pfc-temp-bucket"]
          origin_id                = "S3-pfc-temp-bucket"
          origin_access_control_id = module.pfc_cloudfront.cloudfront_oac_id["main_oac"]
        }
      ]

      default_cache_behavior = {
        target_origin_id       = "S3-pfc-temp-bucket"
        viewer_protocol_policy = "redirect-to-https"
        allowed_methods        = ["GET", "HEAD", "OPTIONS"]
        cached_methods         = ["GET", "HEAD"]
        compress               = true

        forwarded_values = {
          query_string = false
          headers      = []
          cookies = {
            forward = "none"
          }
        }

        min_ttl     = 0
        default_ttl = 3600
        max_ttl     = 86400
      }

      ordered_cache_behaviors = [
        {
          path_pattern           = "/api/*"
          target_origin_id       = "S3-pfc-temp-bucket"
          viewer_protocol_policy = "https-only"
          allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
          cached_methods         = ["GET", "HEAD"]

          forwarded_values = {
            query_string = true
            headers      = ["Authorization", "CloudFront-Forwarded-Proto"]
            cookies = {
              forward = "none"
            }
          }

          min_ttl     = 0
          default_ttl = 0
          max_ttl     = 0
          compress    = true
        }
      ]

      restrictions = {
        geo_restriction = {
          restriction_type = "whitelist"
          locations        = ["JP", "US"]
        }
      }

      viewer_certificate = {
        cloudfront_default_certificate = true
        minimum_protocol_version       = "TLSv1.2_2021"
      }

      custom_error_responses = [
        {
          error_code         = 403
          response_code      = 200
          response_page_path = "/index.html"
        },
        {
          error_code         = 404
          response_code      = 200
          response_page_path = "/index.html"
        }
      ]

      tags = {
        Name        = "pfc-cloudfront-distribution"
        Environment = "production"
        Service     = "pfc"
      }
    }
  }
}