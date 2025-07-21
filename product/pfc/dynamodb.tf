module "dynamodb" {
  source  = "../../modules/aws/dynamodb"
  product = local.env.product

  dynamodbs = {
    ParkingSpots = {
      billing_mode = "PAY_PER_REQUEST"
      hash_key     = "link"
      range_key    = "公開日"
      # read_capacity  = 1
      # write_capacity = 1
      hash_key_type = "S"
      attributes = [
        { name = "link", type = "S" }, # パーティションキー属性
        { name = "公開日", type = "S" },  # ソートキー属性
        { name = "取得日", type = "S" }   # GSIのパーティションキー属性を追加
      ]
      ttl = {
        attribute_name = "TimeToExist"
        enabled        = true
      }
      #   global_secondary_indexes = {
      #     "publish-date" = {
      #       hash_key        = "取得日"
      #       projection_type = "ALL"
      #     }
      #   }
    },
  }
}