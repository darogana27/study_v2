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

data "aws_caller_identity" "self" {}

data "aws_ssm_parameter" "ecr_daily_electricity_image_url" {
  name = "/ecr/daily_electricity_url"
}
