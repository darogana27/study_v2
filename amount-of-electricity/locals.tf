locals {
  env = {
    region = "ap-northeast-1"
  }
  name = "electricity"
  account_id = data.aws_caller_identity.self.account_id
}