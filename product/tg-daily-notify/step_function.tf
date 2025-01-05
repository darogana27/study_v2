locals {
  daily_electricity_arn = module.lambda_functions.arns["daily_electricity"]
  line_notify_arn       = module.lambda_functions.arns["line_notify"]
}

module "state_machines" {
  source = "../../modules/aws/step_function"

  state_machine = {
    tg-daily-notify = {
      definition = jsonencode({
        Comment = "A description of my state machine",
        StartAt = "Daily_Electricity",
        States = {
          Daily_Electricity = {
            Type       = "Task",
            Resource   = "arn:aws:states:::lambda:invoke",
            OutputPath = "$.Payload",
            Parameters = {
              "Payload.$"  = "$",
              FunctionName = local.daily_electricity_arn
            },
            Retry = [
              {
                ErrorEquals = [
                  "Lambda.ServiceException",
                  "Lambda.AWSLambdaException",
                  "Lambda.SdkClientException",
                  "Lambda.TooManyRequestsException",
                  "CustomError"
                ],
                IntervalSeconds = 1,
                MaxAttempts     = 3,
                BackoffRate     = 2,
                Comment         = "Retry the Daily Electricity Lambda function in case of failure"
              }
            ],
            Catch = [
              {
                ErrorEquals = [
                  "States.ALL",
                ],
                Next = "Retry_Daily_Electricity"
              }
            ],
            Next = "Line_Notify"
          },
          Retry_Daily_Electricity = {
            Type       = "Task",
            Resource   = "arn:aws:states:::lambda:invoke",
            OutputPath = "$.Payload",
            Parameters = {
              "Payload.$"  = "$",
              FunctionName = local.daily_electricity_arn
            },
            Retry = [
              {
                ErrorEquals = [
                  "Lambda.ServiceException",
                  "Lambda.AWSLambdaException",
                  "Lambda.SdkClientException",
                  "Lambda.TooManyRequestsException",
                  "CustomError"
                ],
                IntervalSeconds = 1,
                MaxAttempts     = 3,
                BackoffRate     = 2,
                Comment         = "Retry the Daily Electricity Lambda function in case of failure"
              }
            ],
            End = true
          },
          Line_Notify = {
            Type       = "Task",
            Resource   = "arn:aws:states:::lambda:invoke",
            OutputPath = "$.Payload",
            Parameters = {
              "Payload.$"  = "$",
              FunctionName = local.line_notify_arn
            },
            Retry = [
              {
                ErrorEquals = [
                  "Lambda.ServiceException",
                  "Lambda.AWSLambdaException",
                  "Lambda.SdkClientException",
                  "Lambda.TooManyRequestsException",
                  "CustomError"
                ],
                IntervalSeconds = 1,
                MaxAttempts     = 3,
                BackoffRate     = 2,
                Comment         = "Retry the Line Notify Lambda function in case of failure"
              }
            ],
            End = true
          }
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

output "state_machine_arns" {
  description = "List of state machine ARNs"
  value       = module.state_machines.state_machine_arns
}