module "dynamodb" {
  source  = "../../../modules/aws/dynamodb"
  product = local.env.product

  dynamodbs = {
    ParkingSpots = {
      billing_mode  = "PAY_PER_REQUEST"
      hash_key      = "id"
      hash_key_type = "S"
      attributes = [
        { name = "id", type = "S" } # パーティションキー属性
      ]
    }
  }
}