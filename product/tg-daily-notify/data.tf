# 現在のAWSアカウントのID、ARN、およびアカウント番号を取得
data "aws_caller_identity" "self" {}

# 現在のAWSリージョンを取得
data "aws_region" "self" {}

# ECRイメージURLを取得するためのSSMパラメータを参照
data "aws_ssm_parameter" "ecr_daily_electricity_image_url" {
  name = "/ecr/daily_electricity_url" # パラメータストアのキー名
}
