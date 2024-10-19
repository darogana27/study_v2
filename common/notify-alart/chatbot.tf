resource "aws_sns_topic" "it" {
  name = "nottify-alarm-terraform"
}

# これは一旦後で
resource "aws_sns_topic_subscription" "it" {
  topic_arn = aws_sns_topic.it.arn
  protocol  = "https"
  endpoint  = "https://global.sns-api.chatbot.amazonaws.com"
}

resource "aws_chatbot_slack_channel_configuration" "it" {
  configuration_name = "Cloudwatch-Alarm"
  iam_role_arn       = "arn:aws:iam::671522354054:role/service-role/testrole"
  slack_channel_id   = "C07HDEHUE11"
  slack_team_id      = "T07GZ1D0BD5"

  tags = {
    Name = "notify-alarm"
  }
}