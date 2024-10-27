variable "state_machine" {
  description = "ステートマシン作成に必要な設定"
  type = map(object({
    definition = optional(string)
    additional_policies = optional(list(object({
      effect    = string
      actions   = list(string)
      resources = list(string)
    })), [])
  }))
}

variable "account_id" {
  description = "AWSアカウントID"
  type        = string
}

variable "region" {
  description = "AWSリージョン"
  type        = string
}