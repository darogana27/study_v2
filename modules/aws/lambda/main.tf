resource "aws_lambda_function" "it" {
  for_each = var.lambda_functions

  function_name = format("%s-%s-function", var.product, each.key)
  role          = aws_iam_role.it[each.key].arn
  description   = each.value.description
  runtime       = each.value.image_uri != null ? null : each.value.runtime
  filename      = each.value.image_uri == null ? try(each.value.filename) : null
  handler       = each.value.image_uri == null ? each.value.handler : null
  timeout       = each.value.timeout
  # image_uriはpackage_typeがImageの場合のみ設定
  image_uri                      = each.value.image_uri != null ? each.value.image_uri : null
  package_type                   = each.value.image_uri != null ? "Image" : "Zip"
  publish                        = each.value.publish
  reserved_concurrent_executions = each.value.reserved_concurrent_executions
  memory_size                    = each.value.memory_size
  ephemeral_storage {
    size = each.value.size
  }
  
  dynamic "environment" {
    for_each = length(each.value.environment_variables) > 0 ? [each.value.environment_variables] : []
    content {
      variables = environment.value
    }
  }
  
  tags = {
    Name      = "${var.product}-${each.key}"
    ManagedBy = "terraform"
  }

  depends_on = [aws_cloudwatch_log_group.it]

  lifecycle {
    ignore_changes = [
      layers,
      image_uri
    ]
  }
}

resource "aws_cloudwatch_log_group" "it" {
  for_each = var.lambda_functions

  name              = "/aws/lambda/${var.product}-${each.key}-function"
  retention_in_days = 30
  tags = {
    Name      = "${var.product}-${each.key}"
    ManagedBy = "terraform"
  }
}

resource "aws_iam_role" "it" {
  for_each = var.lambda_functions

  name               = format("%s-%s-function-role", var.product, each.key)
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
  tags = {
    Name      = "${var.product}-${each.key}"
    ManagedBy = "terraform"
  }
}

resource "aws_iam_role_policy_attachment" "it" {
  for_each = var.lambda_functions

  role       = aws_iam_role.it[each.key].name
  policy_arn = aws_iam_policy.it[each.key].arn
}

resource "aws_iam_policy" "it" {
  for_each = var.lambda_functions

  name = format("%s-%s-function-policy", var.product, each.key)

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = concat(
      # `need_sqs_trigger` が true の場合のみ SQS パーミッションを追加
      each.value.need_sqs_trigger ? [
        {
          Effect   = "Allow",
          Action   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"],
          Resource = module.sqs_queues[each.key].arn[each.key] # シンプルなリスト参照
        }
      ] : [],
      # 他の IAM ポリシー
      [
        for p in coalesce(each.value.iam_policies, []) : {
          Effect   = p.effect,
          Action   = p.actions,
          Resource = p.resources
        }
      ],
      [
        for p in coalesce(each.value.additional_iam_policies, []) : {
          Effect   = p.effect,
          Action   = p.actions,
          Resource = p.resources
        }
      ]
    )
  })
}

# Lambda関数ごとにSQSモジュールを呼び出し
module "sqs_queues" {
  source = "../sqs"

  product = var.product

  for_each = {
    for key, lf in var.lambda_functions : key => lf
    if lf.need_sqs_trigger
  }

  sqs = {
    (each.key) = merge(
      try(each.value.sqs_config, {}),
      {
        visibility_timeout_seconds = each.value.timeout
      }
    )
  }
}

# SQSトリガーをLambdaに紐付ける (SQSキューが作成された場合のみ)
resource "aws_lambda_event_source_mapping" "it" {
  for_each = {
    for key, lf in var.lambda_functions : key => lf
    if lf.need_sqs_trigger
  }

  # 各 SQS キューの ARN を取得
  event_source_arn = module.sqs_queues[each.key].arn[each.key]
  function_name    = aws_lambda_function.it[each.key].arn

  depends_on = [

    aws_iam_policy.it,
    aws_iam_role_policy_attachment.it,
    module.sqs_queues
  ]
}
