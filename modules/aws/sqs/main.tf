resource "aws_sqs_queue" "it" {
  for_each                   = var.sqs
  name                       = format("%s-queue", each.key)
  delay_seconds              = try(var.delay_seconds, 90)
  max_message_size           = try(var.max_message_size, 2048)
  message_retention_seconds  = try(var.message_retention_seconds, 86400)
  receive_wait_time_seconds  = try(var.receive_wait_time_seconds, 10)
  visibility_timeout_seconds = try(var.visibility_timeout_seconds, 10) # Lambda 関数のタイムアウトを設定
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.deadletter[each.key].arn
    maxReceiveCount     = 4
  })

  tags = {
    Name = each.key
  }
}

resource "aws_sqs_queue" "deadletter" {
  for_each = var.sqs
  name     = format("%s-queue_deadletter", each.key)

  tags = {
    Name = each.key
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