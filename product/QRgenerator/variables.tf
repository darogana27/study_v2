variable "environment" {
  description = "環境名を指定します"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "プロジェクト名を指定します"
  type        = string
  default     = "qr-generator"
}

variable "region" {
  description = "AWSリージョンを指定します"
  type        = string
  default     = "us-east-1"
}

variable "tags" {
  description = "リソースに付与するタグを指定します"
  type        = map(string)
  default     = {}
}