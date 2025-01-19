output "state_machine_arns" {
  description = "List of state machine ARNs"
  value = {
    for k, v in aws_sfn_state_machine.it : k => v.arn
  }
}