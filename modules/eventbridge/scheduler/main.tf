resource "aws_scheduler_schedule" "it" {
  name = format("%s-scheduler", var.schedule_name)

  flexible_time_window {
    mode = var.flexible_time_window
  }

  schedule_expression = var.schedule_expression

  target {
    arn      = var.target_arn
    role_arn = var.role_arn

    input = length(var.input_message_body) > 0 && length(var.input_queue_url) > 0 ? jsonencode({
      MessageBody = var.input_message_body,
      QueueUrl    = var.input_queue_url
    }) : null
  }
}

resource "aws_scheduler_schedule_group" "example" {
  name = format("%s-scheduler-group", var.schedule_name)
}