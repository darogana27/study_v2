variable "name" {
  description = "ステートマシン名"
  type        = string
}

variable "step_function_actions" {
  description = "ステートマシンに付与する権限"
  type        = list(string)
  default     = [
    "states:StartExecution", 
    "states:StopExecution", 
    "states:DescribeExecution", 
    "states:ListExecutions",
    "lambda:InvokeFunction"
    ]
}

variable "definition" {
  description = "定義(JSONで)"
  type        = string
}