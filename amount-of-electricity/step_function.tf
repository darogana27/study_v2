module "step_function" {
  source     = "../modules/step_function"
  name       = "amount-of-electricity"
  definition = <<EOF
{
  "Comment": "A description of my state machine",
  "StartAt": "Dayliy Electricity",
  "States": {
    "Dayliy Electricity": {
      "Type": "Task",
      "Resource": "arn:aws:states:::lambda:invoke",
      "OutputPath": "$.Payload",
      "Parameters": {
        "Payload.$": "$",
        "FunctionName": "${module.lambda_functions.arns.daily_electricity}"
      },
      "Retry": [
        {
          "ErrorEquals": [
            "Lambda.ServiceException",
            "Lambda.AWSLambdaException",
            "Lambda.SdkClientException",
            "Lambda.TooManyRequestsException"
          ],
          "IntervalSeconds": 1,
          "MaxAttempts": 3,
          "BackoffRate": 2,
          "Comment": "Retry the Dayliy Electricity Lambda function in case of failure"
        }
      ],
      "Catch": [
        {
          "ErrorEquals": [
            "States.ALL"
          ],
          "Next": "Retry Dayliy Electricity"
        }
      ],
      "Next": "Line Notify"
    },
    "Retry Dayliy Electricity": {
      "Type": "Task",
      "Resource": "arn:aws:states:::lambda:invoke",
      "OutputPath": "$.Payload",
      "Parameters": {
        "Payload.$": "$",
        "FunctionName": "${module.lambda_functions.arns.daily_electricity}"
      },
      "Retry": [
        {
          "ErrorEquals": [
            "Lambda.ServiceException",
            "Lambda.AWSLambdaException",
            "Lambda.SdkClientException",
            "Lambda.TooManyRequestsException"
          ],
          "IntervalSeconds": 1,
          "MaxAttempts": 3,
          "BackoffRate": 2,
          "Comment": "Retry the Dayliy Electricity Lambda function in case of failure"
        }
      ],
      "End": true
    },
    "Line Notify": {
      "Type": "Task",
      "Resource": "arn:aws:states:::lambda:invoke",
      "OutputPath": "$.Payload",
      "Parameters": {
        "Payload.$": "$",
        "FunctionName": "${module.lambda_functions.arns.line_notify}"
      },
      "Retry": [
        {
          "ErrorEquals": [
            "Lambda.ServiceException",
            "Lambda.AWSLambdaException",
            "Lambda.SdkClientException",
            "Lambda.TooManyRequestsException"
          ],
          "IntervalSeconds": 1,
          "MaxAttempts": 3,
          "BackoffRate": 2,
          "Comment": "Retry the Line Notify Lambda function in case of failure"
        }
      ],
      "End": true
    }
  }
}
EOF
}

output "step_function_arn" {
  value       = module.step_function.state_machine_arn
  description = "Step FunctionのARN"
}