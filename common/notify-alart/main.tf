module "sns" {
  source = "../../modules/aws/sns"

  product = local.env.product

  sns = {
    notify-alarm-for-slack = {
      # protocol = https
      endpoint = "https://global.sns-api.chatbot.amazonaws.com"
    }
  }
}

resource "aws_chatbot_slack_channel_configuration" "it" {
  configuration_name = "Cloudwatch-Alarm"
  iam_role_arn       = aws_iam_role.it.arn
  slack_channel_id   = "C07HDEHUE11"
  slack_team_id      = "T07GZ1D0BD5"
}

resource "aws_iam_role" "it" {
  name               = "AWSChatbot_for_Slack_role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json

}

resource "aws_iam_policy" "policy" {
  name        = "Cloudwatch-Alarm-policy"
  description = "Cloudwatch Alarm policy"
  policy      = data.aws_iam_policy_document.policy.json
}

resource "aws_iam_role_policy_attachment" "policy" {
  role       = aws_iam_role.it.name
  policy_arn = aws_iam_policy.policy.arn
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["chatbot.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy_document" "policy" {
  statement {

    effect    = "Allow"
    actions   = ["cloudwatch:GetMetricWidgetImage"]
    resources = ["*"]
  }
}