output "arn" {
  value       = { for k, v in aws_sqs_queue.it : k => v.arn }
  description = "各sqs関数のARN"
}