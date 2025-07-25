resource "aws_cloudfront_origin_access_control" "it" {
  for_each = var.cloudfront_oac

  name                              = each.value.name
  description                       = each.value.description
  origin_access_control_origin_type = each.value.origin_access_control_origin_type
  signing_behavior                  = each.value.signing_behavior
  signing_protocol                  = each.value.signing_protocol
}