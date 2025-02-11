resource "aws_ssm_parameter" "this" {
  for_each = var.parameters

  name = format("/%s/%s", var.product, coalesce(each.value.name, each.key))

  type  = each.value.type
  value = each.value.value
  tier  = each.value.tier

  tags = merge(
    {
      Name    = "${var.product}-${each.key}"
      product = var.product
    },
    each.value.tags    
  )

  lifecycle {
    ignore_changes = [value]
  }
}