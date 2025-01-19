module "dynamodb" {
  source = "../../modules/aws/dynamodb"

  product = local.env.product

  dynamodbs = {
    electricity = {
      billing_mode = "PAY_PER_REQUEST"
      hash_key     = "YYYYMMDD"
      range_key    = "ElectricityUsage"
      # read_capacity  = 1
      # write_capacity = 1
      hash_key_type = "S"
      attributes = [
        { name = "YYYYMMDD", type = "S" },        # パーティションキー属性
        { name = "ElectricityUsage", type = "S" } # ソートキー属性
      ]
      ttl = {
        attribute_name = "TimeToExist"
        enabled        = true
      }
    },
  }
}