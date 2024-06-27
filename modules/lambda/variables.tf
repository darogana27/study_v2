variable "function_name" {
  type        = string
  default     = "default"
  description = "Lambda関数名"
}

variable "description" {
  type        = string
  default     = "Maneged by Terrafirn"
  description = "説明"
}

variable "runtime" {
  type        = string
  default     = "python3.12"
  description = "ランタイム"
}

variable "filename" {
  type        = string
  default     = null
  description = "Your/path/filenameを指定"
}

variable "handler" {
  type        = string
  default     = "lambda_function.lambda_handler"
  description = "ハンドラー"
}

variable "timeout" {
  type        = number
  default     = 3
  description = "タイムアウト"
}

variable "image_url" {
  type        = string
  default     = null
  description = "DockerImageを使用する場合にECRのURIを指定"
}

variable "publish" {
  type        = bool
  default     = false
  description = "新しい関数バージョンとして公開するか"
}

variable "reserved_concurrent_executions" {
  type        = number
  default     = -1
  description = "ラムダ関数の予約同時実行数"
}

variable "memory_size" {
  type        = number
  default     = 512
  description = "メモリーサイズ"
}

variable "size" {
  type        = number
  default     = 512
  description = "一時ストレージのサイズ (MB 単位)"
}
