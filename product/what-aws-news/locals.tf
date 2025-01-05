locals {
  env = {
    product    = "what-aws-news"
    region     = data.aws_region.self.name
    account_id = data.aws_caller_identity.self.account_id
  }
}