resource "aws_iam_role" "it" {
  name = "${var.schedule_name}-schedule-role"

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
  name = "${var.schedule_name}-scheduler-policy"
  role = aws_iam_role.it.id
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "sqs:SendMessage"
      ],
      "Resource": "${var.target_arn}"
    }
  ]
}
EOF
}
