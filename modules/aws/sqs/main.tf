variable "product" {
  description = "product名"
  type        = string
}

resource "aws_sqs_queue" "it" {
  for_each                   = var.sqs
  name                       = format("%s-%s-queue", var.product, each.key)
  delay_seconds              = each.value.delay_seconds
  max_message_size           = each.value.max_message_size
  message_retention_seconds  = each.value.message_retention_seconds
  receive_wait_time_seconds  = each.value.receive_wait_time_seconds
  visibility_timeout_seconds = each.value.visibility_timeout_seconds
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.deadletter[each.key].arn
    maxReceiveCount     = 4
  })

  tags = {
    Name    = each.key
    product = var.product
  }
}

resource "aws_sqs_queue" "deadletter" {
  for_each = var.sqs
  name     = format("%s-%s-queue-deadletter", var.product, each.key)

  tags = {
    Name    = each.key
    product = var.product
  }
}

data "aws_iam_policy_document" "it" {
  for_each = var.sqs

  statement {
    sid    = "First"
    effect = "Allow"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.it[each.key].arn] # 各キューのARNを参照
  }
}

resource "aws_sqs_queue_policy" "it" {
  for_each  = var.sqs
  queue_url = aws_sqs_queue.it[each.key].id
  policy    = data.aws_iam_policy_document.it[each.key].json # 各ポリシーを参照

  depends_on = [aws_sqs_queue.it] # SQSキューが先に作成されるよう依存関係を設定
}