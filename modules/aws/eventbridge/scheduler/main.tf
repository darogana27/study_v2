resource "aws_scheduler_schedule" "it" {
  for_each   = var.schedules
  name       = format("%s-%s-scheduler", var.product, each.key)
  group_name = aws_scheduler_schedule_group.it.name

  flexible_time_window {
    mode = each.value.flexible_time_window
  }

  schedule_expression          = each.value.schedule_expression
  schedule_expression_timezone = "Japan"

  target {
    arn      = each.value.use_step_function ? module.state_machines[each.key].state_machine_arns[keys(module.state_machines[each.key].state_machine_arns)[0]] : each.value.target_arn
    role_arn = aws_iam_role.it[each.key].arn

    input = length(each.value.input_message_body) > 0 && length(each.value.input_queue_url) > 0 ? jsonencode({
      MessageBody = each.value.input_message_body,
      QueueUrl    = each.value.input_queue_url
    }) : null
  }
}

resource "aws_scheduler_schedule_group" "it" {
  name = format("%s-scheduler-group", var.product
  )
}

resource "aws_iam_role" "it" {
  for_each = var.schedules

  name = format("%s-%s-schedule-role", var.product, each.key)

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

  name = format("%s-%s-scheduler-policy", var.product, each.key)
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
            "arn:aws:states:${var.region}:${var.account_id}:stateMachine:${each.key}-state-machine"
          ]
        },
        {
          Effect   = "Allow"
          Action   = ["lambda:InvokeFunction"]
          Resource = ["arn:aws:lambda:${var.region}:${var.account_id}:function:${each.key}-*"]
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

module "state_machines" {
  source = "../../step_function"

  for_each = {
    for k, v in var.schedules : k => v
    if v.use_step_function
  }

  product = var.product
  state_machine = {
    # scheduleのkeyを使用して動的に生成
    "${each.key}" = {
      additional_policies = [
        {
          effect = "Allow"
          actions = [
            "lambda:InvokeFunction",
          ]
          resources = [
            "arn:aws:lambda:${var.region}:${var.account_id}:function:*"
          ]
        }
      ]
    }
  }

  account_id = var.account_id
  region     = var.region
}