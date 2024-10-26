resource "aws_scheduler_schedule" "it" {
  for_each = var.schedules

  name       = format("%s-scheduler", each.value.schedule_name)
  group_name = aws_scheduler_schedule_group.it[each.key].name

  flexible_time_window {
    mode = each.value.flexible_time_window
  }

  schedule_expression          = each.value.schedule_expression
  schedule_expression_timezone = "Japan"

  target {
    arn      = each.value.target_arn
    role_arn = aws_iam_role.it[each.key].arn

    input = length(each.value.input_message_body) > 0 && length(each.value.input_queue_url) > 0 ? jsonencode({
      MessageBody = each.value.input_message_body,
      QueueUrl    = each.value.input_queue_url
    }) : null
  }
}

resource "aws_scheduler_schedule_group" "it" {
  for_each = var.schedules

  name = format("%s-scheduler-group", each.value.schedule_name)
}

resource "aws_iam_role" "it" {
  for_each = var.schedules

  name = format("%s-schedule-role", each.value.schedule_name)

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "scheduler.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "it" {
  for_each = var.schedules

  name = format("%s-scheduler-policy", each.value.schedule_name)
  role = aws_iam_role.it[each.key].id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = concat(
      [
        {
          Effect = "Allow",
          Action = [
            "states:StartExecution",
            "states:StopExecution",
            "states:DescribeExecution",
            "states:GetExecutionHistory"
          ],
          Resource = [
            "arn:aws:states:${var.region}:${var.account_id}:stateMachine:${each.value.schedule_name}-state-machine"
          ]
        },
        {
          Effect = "Allow"
          Action = ["lambda:InvokeFunction"]
          Resource = ["arn:aws:lambda:${var.region}:${var.account_id}:function:${each.value.schedule_name}-*"]
        }
      ],
      [
        for policy in each.value.additional_policies : {
          Effect   = policy.effect
          Action   = policy.actions
          Resource = policy.resources
        }
      ]
    )
  })
}