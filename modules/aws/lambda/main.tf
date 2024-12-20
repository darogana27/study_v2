resource "aws_lambda_function" "it" {
  for_each = var.lambda_functions

  function_name = format("%s-function", each.key)
  role          = aws_iam_role.it[each.key].arn
  description   = each.value.description
  runtime       = each.value.filename == null ? null : each.value.runtime
  filename      = try(each.value.filename)
  handler       = each.value.filename == null ? null : each.value.handler
  timeout       = each.value.timeout
  # image_uriが存在する場合はその値を使用
  image_uri                      = try(each.value.image_uri, null)
  package_type                   = each.value.image_uri != null ? "Image" : "Zip"
  publish                        = each.value.publish
  reserved_concurrent_executions = each.value.reserved_concurrent_executions
  memory_size                    = each.value.memory_size
  ephemeral_storage {
    size = each.value.size
  }
  tags = {
    Name = each.key
  }

  depends_on = [aws_cloudwatch_log_group.it]

  lifecycle {
    ignore_changes = [
      "layers"
    ]
  }
}

resource "aws_cloudwatch_log_group" "it" {
  for_each = var.lambda_functions

  name              = "/aws/lambda/${each.key}-function"
  retention_in_days = 30
  tags = {
    Name = each.key
  }
}

resource "aws_iam_role" "it" {
  for_each = var.lambda_functions

  name               = format("%s-function-role", each.key)
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
  tags = {
    Name = each.key
  }
}

resource "aws_iam_role_policy_attachment" "it" {
  for_each = var.lambda_functions

  role       = aws_iam_role.it[each.key].name
  policy_arn = aws_iam_policy.it[each.key].arn
}

resource "aws_iam_policy" "it" {
  for_each = var.lambda_functions

  name = format("%s-function-policy", each.key)

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = concat(
      [
        for p in coalesce(each.value.iam_policies, []) : {
          Effect   = p.effect
          Action   = p.actions
          Resource = p.resources
        }
      ],
      [
        for p in coalesce(each.value.additional_iam_policies, []) : {
          Effect   = p.effect
          Action   = p.actions
          Resource = p.resources
        }
      ]
    )
  })
}