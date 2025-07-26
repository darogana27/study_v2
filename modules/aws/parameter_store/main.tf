resource "aws_ssm_parameter" "this" {
  for_each = var.parameters

  name = format("/%s/%s", var.product, coalesce(each.value.name, each.key))

  type  = each.value.type
  value = each.value.value
  tier  = each.value.tier

  tags = {
    Name      = "${var.product}-${each.key}"
    ManagedBy = "terraform"
  }

  lifecycle {
    ignore_changes = [value]
  }
}