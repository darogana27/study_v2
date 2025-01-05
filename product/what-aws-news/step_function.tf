module "state_machines" {
  source = "../../modules/aws/step_function"

  state_machine = {
    tg-daily-notify = {
      definition = jsonencode({
        Comment = "A description of my state machine",
        StartAt = "Daily_Electricity",
        States = {
        }
      })
      additional_policies = [
        {
          effect = "Allow"
          actions = [
            "lambda:InvokeFunction",
          ]
          resources = [
            "arn:aws:lambda:${local.env.region}:${local.env.account_id}:function:*"
          ]
        }
      ]

    },
  }

  account_id = data.aws_caller_identity.self.account_id
  region     = data.aws_region.self.name
}