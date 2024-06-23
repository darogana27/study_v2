data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "iam_for_lambda" {
  name               = "iam_for_lambda"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_role_policy_attachment" "lambda_execution_policy" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = aws_iam_policy.lambda_add_policy.arn
}

resource "aws_iam_policy" "lambda_add_policy" {
  name = "lambda_add_policy"

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
          "s3:GetObject"
        ],
        Resource = [
            "arn:aws:s3:::amount-of-electricity/*",
            # 一旦仮で。後で消す
            "arn:aws:s3:::tokyo-gas-electricity/*"
            ]
      }
    ]
  })
}

resource "aws_lambda_function" "Line_Notify" {
  filename      = "${path.module}/lambda/Line_Notify.zip"
  function_name = "Line_Notify"
  role          = aws_iam_role.iam_for_lambda.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.12"
  timeout       = 5

  ephemeral_storage {
    size = 1024 # Min 512 MB and the Max 10240 MB
  }
}