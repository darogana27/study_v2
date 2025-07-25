variable "cloudfront_oac" {
  description = "CloudFront Origin Access Control の設定"
  type = map(object({
    name                              = string
    description                       = string
    origin_access_control_origin_type = string
    signing_behavior                  = string
    signing_protocol                  = string
  }))
  default = {}
}