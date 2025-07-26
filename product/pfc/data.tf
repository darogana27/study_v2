# 現在のAWSアカウントのID、ARN、およびアカウント番号を取得
data "aws_caller_identity" "self" {}

# 現在のAWSリージョンを取得
data "aws_region" "self" {}
