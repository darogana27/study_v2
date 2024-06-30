
# AWS EventBridge スケジューラーモジュール

このTerraformモジュールは、AWS EventBridgeスケジューラを必要なIAMロールとポリシーで作成します。

## 使用方法

このモジュールを使用するには、Terraform構成に以下のように含めてください：

```hcl
provider "aws" {
  region = "us-west-2"  # 必要に応じてリージョンを調整してください
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

module "state_machines" {
  source = "./path/to/state_machines_module"  # ステートマシンモジュールへのパスを調整してください

  state_machine = {
    amount_of_electricity = {
      name       = "amount-of-electricity"
      definition = file("./definitions/amount-of-electricity.asl.json")  # 定義ファイルへのパス
      additional_policies = []
    },
    another_step_function = {
      name       = "another-step-function"
      definition = file("./definitions/another-step-function.asl.json")  # 定義ファイルへのパス
      additional_policies = []
    }
  }

  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name
}

module "schedulers" {
  source = "../modules/eventbridge/scheduler"  # スケジューラーモジュールへのパスを調整してください

  schedules = {
    schedule_1 = {
      schedule_name = "amount-of-electricity-schedule"
      target_arn    = module.state_machines.state_machine_arns["amount_of_electricity"]
      schedule_expression  = "cron(0 21 * * ? *)"
    },
    schedule_2 = {
      schedule_name = "another-step-function-schedule"
      target_arn    = module.state_machines.state_machine_arns["another_step_function"]
      schedule_expression  = "rate(5 minutes)"
    }
  }

  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name
}

output "state_machine_names" {
  description = "ステートマシン名のリスト"
  value = module.state_machines.state_machine_names
}

output "state_machine_arns" {
  description = "ステートマシンARNのマップ"
  value = module.state_machines.state_machine_arns
}
```

## 変数

### `schedules`

作成するスケジュールのマップ。各スケジュールは以下の属性で定義されます：

- `schedule_name` (string): スケジュールの名前。
- `flexible_time_window` (optional, string, default = "OFF"): 柔軟な時間ウィンドウのモード。
- `schedule_expression` (optional, string, default = "cron(0 21 * * ? *)"): スケジュール表現。
- `target_arn` (string): ターゲットリソースのARN。
- `input_message_body` (optional, string, default = ""): メッセージ本文の入力。
- `input_queue_url` (optional, string, default = ""): キューURLの入力。
- `additional_policies` (optional, list(object)): 追加のポリシー。

### `account_id`

- description: AWSアカウントID
- type: string

### `region`

- description: AWSリージョン
- type: string
