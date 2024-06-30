module "state_machines" {
  source = "../modules/step_function"

  state_machine = {
    amount-of-electricity = {
      name       = "amount-of-electricity"
      definition = file("./definitions/amount-of-electricity.asl.json") # 定義ファイルのパスを指定してください
      # additional_policies = []
    },
  }

  account_id = data.aws_caller_identity.self.account_id
  region     = data.aws_region.self.name
}

output "state_machine_arns" {
  description = "List of state machine ARNs"
  value       = module.state_machines.state_machine_arns
}