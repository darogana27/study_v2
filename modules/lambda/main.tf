resource "aws_lambda_function" "it" {
  function_name                  = format("%s-function", var.function_name)
  role                           = aws_iam_role.it.arn
  description                    = try(var.description, "Maneged by Terraform")
  runtime                        = try(var.runtime, "python3.12")
  filename                       = var.filename
  handler                        = try(var.handler, "lambda_function.lambda_handler")
  timeout                        = try(var.timeout, "60")
  image_uri                      = try(var.image_url, null)
  package_type                   = var.image_url != null ? "Image" : "Zip"
  publish                        = var.publish
  reserved_concurrent_executions = var.reserved_concurrent_executions
  memory_size                    = var.memory_size
  ephemeral_storage {
    size = var.size
  }
  depends_on = [
    aws_cloudwatch_log_group.it
  ]
  tags = {
    Name = var.function_name
  }
}

resource "aws_cloudwatch_log_group" "it" {
  name              = "/aws/lambda/${var.function_name}-function"
  retention_in_days = 30
  tags = {
    Name = var.function_name
  }
}

resource "aws_iam_role" "it" {
  name               = format("%s-function-role", var.function_name)
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
  tags = {
    Name = var.function_name
  }
}

resource "aws_iam_role_policy_attachment" "it" {
  role       = aws_iam_role.it.name
  policy_arn = aws_iam_policy.it.arn
}

resource "aws_iam_policy" "it" {
  name = format("%s-function-policy", var.function_name)

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ssm:GetParameter"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "s3:PutObject"
        ],
        Resource = [
          "arn:aws:s3:::amount-of-electricity/*",
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
        ]
        Resource = ["arn:aws:logs:*:*:*"]
      }
    ]
  })
}