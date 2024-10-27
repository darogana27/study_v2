data "aws_caller_identity" "self" {}
data "aws_region" "self" {}

data "aws_ssm_parameter" "ecr_daily_electricity_image_url" {
  name = "/ecr/daily_electricity_url"
}