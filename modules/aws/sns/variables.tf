variable "sns" {
  description = "sns_topicの定義を設定します"
  type = map(object({
    topic_name = string
    protocol   = optional(string, "https")
    endpoint   = optional(string, null)
  }))
}