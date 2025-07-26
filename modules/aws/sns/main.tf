locals {
  # topic_nameが設定されている場合はその値を、そうでない場合はeach.keyを使用
  topics = {
    for k, v in var.sns : k => merge(v, {
      name = coalesce(lookup(v, "topic_name", null), k)
    })
  }
}

resource "aws_sns_topic" "it" {
  for_each = local.topics
  name     = format("%s-topic", each.value.name)

  tags = {
    Name      = "${var.product}-${each.key}"
    ManagedBy = "terraform"
  }
}

# これは一旦後で
resource "aws_sns_topic_subscription" "it" {
  for_each  = { for k, v in var.sns : k => v if v.endpoint != null }
  topic_arn = aws_sns_topic.it[each.key].arn
  protocol  = each.value.protocol
  endpoint  = each.value.endpoint
}