resource "aws_iam_role" "it" {
  name = "${var.name}_step_function_role"

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
  name   = "${var.name}_step_function_policy"
  role   = aws_iam_role.it.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = var.step_function_actions,
        Resource = "*"
      }
    ]
  })
}

resource "aws_sfn_state_machine" "state_machine" {
  name     = "${var.name}-state-machine"
  role_arn = aws_iam_role.it.arn

  definition = var.definition
}