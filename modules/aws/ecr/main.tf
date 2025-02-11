resource "aws_ecr_repository" "it" {
  for_each = var.repositories

  name                 = format("%s/%s", var.product, each.key)
  image_tag_mutability = each.value.image_tag_mutability
  force_delete         = each.value.force_delete

  image_scanning_configuration {
    scan_on_push = each.value.scan_on_push
  }

  tags = {
    Name    = "${var.product}-${each.key}"
    product = var.product
  }
}