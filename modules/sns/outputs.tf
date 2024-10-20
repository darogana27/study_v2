output "sns_topic_ids" {
  value = { for k, v in aws_sns_topic.it : k => v.arn }
}

output "aws_sns_topic_subscription" {
  value = { for k, v in aws_sns_topic_subscription.it : k => v.id }
}