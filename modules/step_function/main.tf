resource "aws_sfn_state_machine" "it" {
  for_each = var.state_machine

  name       = "${each.value.name}-state-machine"
  role_arn   = aws_iam_role.it[each.key].arn
  definition = each.value.definition
}

resource "aws_iam_role" "it" {
  for_each = var.state_machine

  name = format("%s_step_function_role", each.value.name)
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
}

resource "aws_iam_role_policy" "it" {
  for_each = var.state_machine

  name = format("%s_step_function_policy", each.value.name)
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
            "arn:aws:states:${var.region}:${var.account_id}:stateMachine:${each.value.name}-state-machine"
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