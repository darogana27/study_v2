variable "product" {
  description = "product名"
  type        = string
}

variable "environment" {
  description = "環境名"
  type        = string
  default     = null
}

variable "repositories" {
  description = "Map of ECR repositories to create"
  type = map(object({
    image_tag_mutability = optional(string, "IMMUTABLE")
    scan_on_push         = optional(bool, true)
    force_delete         = optional(bool, true)
    # 必要に応じて他のオプションを追加
  }))
}