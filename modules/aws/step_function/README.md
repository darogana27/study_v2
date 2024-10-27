
# AWS Step Functions モジュール

このTerraformモジュールは、AWS Step Functionsを必要なIAMロールとポリシーで作成します。

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

### `state_machine`

作成するステートマシンのマップ。各ステートマシンは以下の属性で定義されます：

- `name` (string): ステートマシンの名前。
- `definition` (optional, string): ステートマシンの定義。
- `additional_policies` (optional, list(object)): 追加のポリシー。

### `account_id`

- description: AWSアカウントID
- type: string

### `region`

- description: AWSリージョン
- type: string

## 出力

### `state_machine_names`

ステートマシン名のリスト。

### `state_machine_arns`

ステートマシンARNのマップ。
