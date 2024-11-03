module "dynamodb" {
  source = "../../modules/aws/dynamodb"
  dynamodbs = {
    twitch-get-games = {
      billing_mode   = "PROVISIONED"
      hash_key       = "user_id"
      range_key      = "user_name"
      read_capacity  = 5
      write_capacity = 5
      hash_key_type  = "S"
      attributes = [
        { name = "user_id", type = "S" },
        { name = "user_name", type = "S" }
      ]
      ttl = {
        attribute_name = "TimeToExist"
        enabled        = true
      }
    },
  }
}