module "dynamodb" {
  source = "../../modules/aws/dynamodb"
  dynamodbs = {
    amount-of-electricity = {
      name           = "amount-of-electricity"
      billing_mode   = "PROVISIONED"
      hash_key       = "YearMonth"
      range_key      = "Day"
      read_capacity  = 5
      write_capacity = 5
      hash_key_type  = "S"
      attributes = [
        { name = "YearMonth", type = "S" },
        { name = "Day", type = "S" },
      ]
      ttl = {
        attribute_name = "TimeToExist"
        enabled        = true
      }
    },
  }
}
