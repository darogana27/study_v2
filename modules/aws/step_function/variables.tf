variable "product" {
  description = "product名"
  type        = string
}

variable "environment" {
  description = "環境名"
  type        = string
  default     = null
}

variable "account_id" {
  description = "AWSアカウントID"
  type        = string
}

variable "region" {
  description = "AWSリージョン"
  type        = string
}

variable "state_machine" {
  description = "ステートマシン作成に必要な設定"
  type = map(object({
    definition = optional(any)
    additional_policies = optional(list(object({
      effect    = string
      actions   = list(string)
      resources = list(string)
    })), [])
  }))
}