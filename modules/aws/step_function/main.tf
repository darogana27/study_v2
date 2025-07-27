locals {

  default_definition = jsonencode({
    Comment = "Default state machine"
    StartAt = "DefaultWaitState"
    States = {
      DefaultWaitState = {
        Type    = "Wait"
        Seconds = 60
        End     = true
      }
    }
  })

  state_machine_definitions = {
    for k, v in var.state_machine : k => (
      v.definition != null ? jsonencode(v.definition) : local.default_definition
    )
  }
}

resource "aws_sfn_state_machine" "it" {
  for_each = var.state_machine

  name       = format("%s-%s-scheduler", var.product, each.key)
  role_arn   = aws_iam_role.it[each.key].arn
  definition = local.state_machine_definitions[each.key]

  lifecycle {
    ignore_changes = [
      definition
    ]
  }

  tags = {
    Name      = "${var.product}-${each.key}"
    ManagedBy = "terraform"
  }
}

resource "aws_iam_role" "it" {
  for_each = var.state_machine

  name = format("%s-%s-step-function-role", var.product, each.key)
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "states.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name      = "${var.product}-${each.key}-role"
    ManagedBy = "terraform"
  }
}

resource "aws_iam_role_policy" "it" {
  for_each = var.state_machine

  name = format("%s-%s-step-fuction-olicy", var.product, each.key)
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