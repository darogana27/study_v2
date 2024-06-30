resource "aws_s3_bucket" "it" {
  for_each = var.s3_bucket

  bucket        = format("%s-bucket", each.value.s3_bucket_name)
  force_destroy = each.value.force_destroy
}

resource "aws_s3_bucket_accelerate_configuration" "it" {
  for_each = var.s3_bucket

  bucket = aws_s3_bucket.it[each.key].id
  status = each.value.accelerate_configuration
}

# resource "aws_s3_bucket_acl" "it" {
#   for_each = var.s3_bucket

#   depends_on = [aws_s3_bucket_ownership_controls.it]

#   bucket = aws_s3_bucket.it[each.key].id
#   acl    = each.value.bucket_acl
# }

resource "aws_s3_bucket_ownership_controls" "it" {
  for_each = var.s3_bucket

  bucket = aws_s3_bucket.it[each.key].id

  rule {
    object_ownership = each.value.object_ownership
  }
}

resource "aws_s3_bucket_metric" "it" {
  for_each = var.s3_bucket

  bucket = aws_s3_bucket.it[each.key].id
  name   = format("%s-metric", each.value.s3_bucket_name)
}

resource "aws_s3_bucket_lifecycle_configuration" "it" {
  for_each = { for k, v in var.s3_bucket : k => v if length(v.lifecycle_rules) > 0 }

  bucket = aws_s3_bucket.it[each.key].id

  dynamic "rule" {
    for_each = each.value.lifecycle_rules
    content {
      id     = rule.value.id
      status = rule.value.enabled ? "Enabled" : "Disabled"

      dynamic "filter" {
        for_each = [rule.value]
        content {
          prefix = rule.value.prefix
        }
      }

      dynamic "transition" {
        for_each = rule.value.transitions
        content {
          days          = transition.value.days
          storage_class = transition.value.storage_class
        }
      }

      dynamic "expiration" {
        for_each = rule.value.expiration != null ? [rule.value.expiration] : []
        content {
          days = expiration.value.days
        }
      }
    }
  }
}

resource "aws_s3_bucket_versioning" "it" {
  for_each = var.s3_bucket

  bucket = aws_s3_bucket.it[each.key].id
  versioning_configuration {
    status = each.value.versioning_status
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "it" {
  for_each = var.s3_bucket

  bucket = aws_s3_bucket.it[each.key].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = each.value.encryption_algorithm
    }
  }
}

# resource "aws_s3_bucket_public_access_block" "it" {
#   for_each = var.s3_bucket

#   bucket                  = aws_s3_bucket.it[each.key].id
#   block_public_acls       = each.value.block_public_acls
#   block_public_policy     = each.value.block_public_policy
#   ignore_public_acls      = each.value.ignore_public_acls
#   restrict_public_buckets = each.value.restrict_public_buckets
# }

resource "aws_s3_bucket_notification" "it" {
  for_each = { for k, v in var.s3_bucket : k => v if length(v.notifications) > 0 }

  bucket = aws_s3_bucket.it[each.key].id

  dynamic "lambda_function" {
    for_each = [for n in each.value.notifications : n if n.lambda_function_arn != null]
    content {
      lambda_function_arn = lambda_function.value.lambda_function_arn
      events              = [lambda_function.value.event_type]
    }
  }

  dynamic "topic" {
    for_each = [for n in each.value.notifications : n if n.topic_arn != null]
    content {
      topic_arn = topic.value.topic_arn
      events    = [topic.value.event_type]
    }
  }

  dynamic "queue" {
    for_each = [for n in each.value.notifications : n if n.queue_arn != null]
    content {
      queue_arn = queue.value.queue_arn
      events    = [queue.value.event_type]
    }
  }
}

