module "dynamodb" {
  source = "../modules/dynamodb"
  dynamodbs = {
    table1 = {
      name           = "example1"
      billing_mode   = "PROVISIONED"
      hash_key       = "id"
      range_key      = "rangeKey"
      read_capacity  = 5
      write_capacity = 5
      hash_key_type  = "S"
      attributes = [
        { name = "id", type = "S" },
        { name = "rangeKey", type = "S" },
        { name = "indexId", type = "S" },
        { name = "indexRange", type = "S" }
      ]
      global_secondary_indexes = [
        {
          name               = "example1-index"
          hash_key           = "indexId"
          range_key          = "indexRange"
          read_capacity      = 5
          write_capacity     = 5
          projection_type    = "INCLUDE"
          non_key_attributes = ["UserId"]
        }
      ]
      ttl = {
        attribute_name = "TimeToExist"
        enabled        = true
      }
    },
    table2 = {
      name          = "example2"
      billing_mode  = "PAY_PER_REQUEST"
      hash_key      = "userId"
      range_key     = "timestamp"
      hash_key_type = "S"
      attributes = [
        { name = "userId", type = "S" },
        { name = "timestamp", type = "S" },
        { name = "indexUserId", type = "S" },
        { name = "indexTimestamp", type = "S" }
      ]
      global_secondary_indexes = [
        {
          name               = "example2-index"
          hash_key           = "indexUserId"
          range_key          = "indexTimestamp"
          projection_type    = "INCLUDE"
          non_key_attributes = ["UserId"]
        }
      ]
      ttl = {
        attribute_name = "ExpirationTime"
        enabled        = true
      }
    }
  }
}
