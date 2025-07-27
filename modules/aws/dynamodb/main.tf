resource "aws_dynamodb_table" "it" {
  for_each = var.dynamodbs

  name         = format("%s-%s-table", var.product, each.key)
  billing_mode = each.value.billing_mode
  hash_key     = each.value.hash_key
  range_key    = lookup(each.value, "range_key", null)

  dynamic "attribute" {
    for_each = each.value.attributes
    content {
      name = attribute.value.name
      type = attribute.value.type
    }
  }

  dynamic "global_secondary_index" {
    for_each = lookup(each.value, "global_secondary_indexes", {}) != null ? each.value.global_secondary_indexes : {}
    content {
      name               = global_secondary_index.key
      hash_key           = global_secondary_index.value.hash_key
      range_key          = lookup(global_secondary_index.value, "range_key", null)
      projection_type    = global_secondary_index.value.projection_type
      non_key_attributes = lookup(global_secondary_index.value, "non_key_attributes", [])
      read_capacity      = each.value.billing_mode == "PROVISIONED" ? lookup(global_secondary_index.value, "read_capacity", 1) : null
      write_capacity     = each.value.billing_mode == "PROVISIONED" ? lookup(global_secondary_index.value, "write_capacity", 1) : null
    }
  }

  dynamic "ttl" {
    for_each = each.value.ttl != null ? [each.value.ttl] : []
    content {
      attribute_name = ttl.value.attribute_name
      enabled        = ttl.value.enabled
    }
  }

  read_capacity  = each.value.billing_mode == "PROVISIONED" ? lookup(each.value, "read_capacity", 1) : null
  write_capacity = each.value.billing_mode == "PROVISIONED" ? lookup(each.value, "write_capacity", 1) : null

  lifecycle {
    ignore_changes = [read_capacity, write_capacity]
  }

  tags = {
    Name      = "${var.product}-${each.key}"
    ManagedBy = "terraform"
  }
}

resource "aws_ssm_parameter" "dynamodb_table_name" {
  for_each = var.dynamodbs
  name     = format("/%s/dynamodb/%s/table-name", var.product, each.key)
  type     = "String"
  value    = aws_dynamodb_table.it[each.key].name

  tags = {
    Name      = "${var.product}-${each.key}"
    ManagedBy = "terraform"
  }
}