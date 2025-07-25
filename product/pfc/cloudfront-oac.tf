module "pfc_cloudfront_oac" {
  source = "../../modules/aws/cloudfront_oac"

  cloudfront_oac = {
    main_oac = {
      name                              = "pfc-s3-oac-final"
      description                       = "OAC for PFC S3 bucket access - final config"
      origin_access_control_origin_type = "s3"
      signing_behavior                  = "always"
      signing_protocol                  = "sigv4"
    }
  }
}