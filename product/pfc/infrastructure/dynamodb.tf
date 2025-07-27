module "dynamodb" {
  source  = "../../../modules/aws/dynamodb"
  product = local.env.product

  dynamodbs = {
    ParkingSpots = {
      billing_mode   = "PAY_PER_REQUEST"
      hash_key       = "id"
      hash_key_type  = "S"
      range_key      = "ward" # 区での効率的な範囲クエリ
      range_key_type = "S"

      attributes = [
        { name = "id", type = "S" },      # パーティションキー
        { name = "ward", type = "S" },    # ソートキー（区名）
        { name = "station", type = "S" }, # 駅名でのGSI
        { name = "geoHash", type = "S" }  # 地理的検索用GeoHash
      ]

      # 駅名検索用GSI
      global_secondary_indexes = {
        StationIndex = {
          name            = "StationIndex"
          hash_key        = "station"
          range_key       = "ward"
          projection_type = "ALL"
        }
        # 地理的検索用GSI
        GeoIndex = {
          name            = "GeoIndex"
          hash_key        = "geoHash"
          range_key       = "id"
          projection_type = "ALL"
        }
        # 区別検索用GSI
        WardIndex = {
          name            = "WardIndex"
          hash_key        = "ward"
          range_key       = "station"
          projection_type = "ALL"
        }
      }
    }
  }
}