variable "product" {
  description = "product名"
  type        = string
}

variable "environment" {
  description = "環境名"
  type        = string
  default     = null
}

variable "parameters" {
  description = "パラメーターストアに登録する値のマップ"
  type = map(object({
    name        = optional(string)
    value       = optional(string, "dummy")
    description = optional(string, null)
    type        = optional(string, "String")
    tier        = optional(string, "Standard")
    tags        = optional(map(string), {})
  }))
}