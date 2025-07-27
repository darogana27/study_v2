# Common Infrastructure

共通インフラリソースを管理するディレクトリです。

## 管理リソース

### 1. Terraform Backend (backend.tf)
- **S3バケット**: `terraform-state-2024-0218`
- **バージョニング**: 有効
- **暗号化**: AES256
- **パブリックアクセス**: ブロック

### 2. Slack Notifications (notifications.tf)
- **AWS Chatbot**: Slack連携設定
- **SNS Topic**: アラーム通知用
- **IAM Role**: Chatbot用権限

## 初回セットアップ

### 1. Terraformの初期化
```bash
cd common
terraform init
```

### 2. 既存S3バケットをインポート
```bash
terraform import aws_s3_bucket.terraform_state terraform-state-2024-0218
```

### 3. 設定を適用
```bash
terraform plan
terraform apply
```

## 使用方法

### 他のプロジェクトからの参照
```hcl
# S3バケット参照
data "terraform_remote_state" "common" {
  backend = "s3"
  config = {
    bucket = "terraform-state-2024-0218"
    key    = "common/terraform.tfstate"
    region = "ap-northeast-1"
  }
}

# SNS Topic ARN取得
sns_topic_arn = data.terraform_remote_state.common.outputs.sns_topic_arn
```

## ファイル構成

```
common/
├── terraform.tf      # Provider設定
├── backend.tf         # S3バックエンド管理
├── notifications.tf   # Slack通知設定
├── outputs.tf         # 出力値
└── README.md         # このファイル
```