output "state_machine_arns" {
  description = "List of state machine ARNs"
  value       = [for key, sm in aws_sfn_state_machine.it : sm.arn]
}