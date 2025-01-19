module "dynamodb" {
  source  = "../../modules/aws/dynamodb"
  product = local.env.product

  dynamodbs = {
    article = {
      billing_mode = "PAY_PER_REQUEST"
      hash_key     = "URL"
      range_key    = "公開日"
      # read_capacity  = 1
      # write_capacity = 1
      hash_key_type = "S"
      attributes = [
        { name = "URL", type = "S" }, # パーティションキー属性
        { name = "公開日", type = "S" }  # ソートキー属性
      ]
      ttl = {
        attribute_name = "TimeToExist"
        enabled        = true
      }
    },
    all_tag_services = {
      billing_mode = "PAY_PER_REQUEST"
      hash_key     = "service_namespace"
      # read_capacity  = 1
      # write_capacity = 1
      hash_key_type = "S"
      attributes = [
        { name = "service_namespace", type = "S" }, # パーティションキー属性
      ]
      ttl = {
        attribute_name = "TimeToExist"
        enabled        = true
      }
    },
  }
}