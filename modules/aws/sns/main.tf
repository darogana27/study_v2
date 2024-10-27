resource "aws_sns_topic" "it" {
  for_each = var.sns
  name     = format("%s-topic", each.value.topic_name)
}

# これは一旦後で
resource "aws_sns_topic_subscription" "it" {
  for_each = { for k, v in var.sns : k => v if v.endpoint != null }
  topic_arn = aws_sns_topic.it[each.key].arn
  protocol  = each.value.protocol
  endpoint  = each.value.endpoint
}