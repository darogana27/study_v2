resource "aws_iam_role" "line_notify_role" {
  name               = "line_notify_role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_role_policy_attachment" "line_notify_policy" {
  role       = aws_iam_role.line_notify_role.name
  policy_arn = aws_iam_policy.line_notify_policy.arn
}

resource "aws_iam_policy" "line_notify_policy" {
  name = "line_notify_policy"

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

resource "aws_lambda_function" "line_notify" {
  filename      = "${path.module}/lambda/Line_Notify.zip"
  function_name = "line_notify"
  role          = aws_iam_role.line_notify_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.12"
  timeout       = 5

  ephemeral_storage {
    size = 1024 # Min 512 MB and the Max 10240 MB
  }
}

resource "aws_ecr_repository" "daily-electricity" {
  name = "daily-electricity"
}

# variable "lambda_image_uri" {
#   description = "The URI of the ECR image to use for the Lambda function"
#   default     = "${local.account_id}.dkr.ecr.${local.env.region}.amazonaws.com/daily-electricity:latest"
# }

resource "aws_iam_role" "daily-electricity_role" {
  name               = "daily-electricity_role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_role_policy_attachment" "daily-electricity_policy" {
  role       = aws_iam_role.daily-electricity_role.name
  policy_arn = aws_iam_policy.daily-electricity_policy.arn
}

resource "aws_iam_policy" "daily-electricity_policy" {
  name = "daily-electricity_policy"

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
      }
    ]
  })
}

resource "aws_lambda_function" "daily-electricity" {
  package_type  = "Image"
  image_uri     = "${local.account_id}.dkr.ecr.${local.env.region}.amazonaws.com/daily-electricity:latest"
  function_name = "daily-electricity"
  role          = aws_iam_role.daily-electricity_role.arn
  memory_size   = 512
  timeout       = 60

  ephemeral_storage {
    size = 1024 # Min 512 MB and the Max 10240 MB
  }
}