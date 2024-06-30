
# Lambda モジュール

このTerraformモジュールは、AWS Lambda関数を作成および管理します。

## 使用方法

このモジュールを使用するには、Terraform構成に含め、必要な変数を提供します。

### 例

```hcl
resource "aws_lambda_function" "it" {
  for_each = var.lambda_functions

  function_name                  = format("%s-function", each.value.function_name)
  role                           = aws_iam_role.it[each.key].arn
  description                    = each.value.description
  runtime                        = each.value.filename == null ? null : each.value.runtime
  filename                       = each.value.filename
  handler                        = each.value.filename == null ? null : each.value.handler
  timeout                        = each.value.timeout
  image_uri                      = each.value.image_uri
  package_type                   = each.value.image_uri != null ? "Image" : "Zip"
  publish                        = each.value.publish
  reserved_concurrent_executions = each.value.reserved_concurrent_executions
  memory_size                    = each.value.memory_size
  ephemeral_storage {
    size = each.value.size
  }
  tags = {
    Name = each.value.function_name
  }

  depends_on = [aws_cloudwatch_log_group.it]
}

resource "aws_cloudwatch_log_group" "it" {
  for_each = var.lambda_functions

  name              = "/aws/lambda/${each.value.function_name}-function"
  retention_in_days = 30
  tags = {
    Name = each.value.function_name
  }
}

resource "aws_iam_role" "it" {
  for_each = var.lambda_functions

  name               = format("%s-function-role", each.value.function_name)
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
  tags = {
    Name = each.value.function_name
  }
}

resource "aws_iam_role_policy_attachment" "it" {
  for_each = var.lambda_functions

  role       = aws_iam_role.it[each.key].name
  policy_arn = aws_iam_policy.it[each.key].arn
}

resource "aws_iam_policy" "it" {
  for_each = var.lambda_functions

  name = format("%s-function-policy", each.value.function_name)

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
```

## 変数

- `lambda_functions`: Lambda関数の設定をマップで定義します

各変数の詳細な設定項目は以下の通りです:

variable "lambda_functions" {
  description = "Lambda関数の設定をマップで定義します"
  type = map(object({
    function_name                  = string                                             # Lambda関数の名前
    filename                       = optional(string, null)                             # Lambda関数のコードが格納されたファイル
    handler                        = optional(string, "lambda_function.lambda_handler") # Lambda関数のハンドラー
    runtime                        = optional(string, "python3.12")                     # Lambda関数のランタイム
    description                    = optional(string, "Managed by Terraform")           # Lambda関数の説明
    timeout                        = optional(number, 60)                               # Lambda関数のタイムアウト（秒）
    memory_size                    = optional(number, 128)                              # Lambda関数のメモリサイズ（MB）
    size                           = optional(number, 512)                              # 一時ストレージのサイズ（MB）
    image_uri                      = optional(string, null)                             # Lambda関数のイメージURI
    publish                        = optional(bool, false)                              # Lambda関数の公開設定
    reserved_concurrent_executions = optional(number, -1)                               # Lambda関数の予約済みの同時実行数
    iam_policies = optional(list(object({
      effect    = string       # IAMポリシーの効果（AllowまたはDeny）
      actions   = list(string) # 許可するアクションのリスト
      resources = list(string) # 許可するリソースのリスト
      })), [                   # デフォルトポリシー
      {
        effect    = "Allow"
        actions   = ["ssm:GetParameter"]
        resources = ["*"]
      },
      {
        effect    = "Allow"
        actions   = ["s3:PutObject"]
        resources = ["arn:aws:s3:::amount-of-electricity/*"]
      },
      {
        effect    = "Allow"
        actions   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        resources = ["arn:aws:logs:*:*:*"]
      }
      ]),
    additional_iam_policies = optional(list(object({ # 追加のポリシー
      effect    = string       
      actions   = list(string)
      resources = list(string)
    })), [])
  }))
}

