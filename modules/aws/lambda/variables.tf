variable "lambda_functions" {
  description = "Lambda関数の設定をマップで定義します"
  type = map(object({
    filename                       = optional(string, "../../modules/aws/lambda/default.zip") # Lambda関数のコードが格納されたファイル
    handler                        = optional(string, "lambda_function.lambda_handler")       # Lambda関数のハンドラー
    runtime                        = optional(string, "python3.12")                           # Lambda関数のランタイム
    description                    = optional(string, "Managed by Terraform")                 # Lambda関数の説明
    timeout                        = optional(number, 60)                                     # Lambda関数のタイムアウト（秒）
    memory_size                    = optional(number, 128)                                    # Lambda関数のメモリサイズ（MB）
    size                           = optional(number, 512)                                    # 一時ストレージのサイズ（MB）
    image_uri                      = optional(string, null)                                   # Lambda関数のイメージURI
    publish                        = optional(bool, false)                                    # Lambda関数の公開設定
    reserved_concurrent_executions = optional(number, -1)                                     # Lambda関数の予約済みの同時実行数
    need_sqs_trigger               = optional(bool, false)
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
        actions   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        resources = ["arn:aws:logs:*:*:*"]
      }
    ]),
    additional_iam_policies = optional(list(object({ # 追加のポリシー
      effect    = string
      actions   = list(string)
      resources = list(string)
    })), [])
    sqs_config = optional(object({
      delay_seconds             = optional(number, 90)
      max_message_size          = optional(number, 2048)
      message_retention_seconds = optional(number, 86400)
      receive_wait_time_seconds = optional(number, 10)
      # visibility_timeout_seconds はLambdaのtimeoutから自動設定
    }))
  }))
}
