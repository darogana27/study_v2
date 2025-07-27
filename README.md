# Terraform Study Project v2

AWS学習用のTerraformプロジェクト管理システムです。

## 🚀 クイックスタート

### 1. バックエンドセットアップ（初回のみ）
```bash
cd backend
terraform init && terraform apply
```

### 2. プロジェクト作成
```bash
make-product -name my-app -region ap-northeast-1
```

### 3. 開発開始
```bash
cd product/my-app
# backend.tfのバケット名を更新後
terraform init && terraform plan
```

## 📁 プロジェクト構成

```
study_v2/
├── backend/              # Terraformバックエンドインフラ
├── docs/                 # ドキュメント
├── modules/              # 再利用可能モジュール
├── product/              # 作成されたプロジェクト
├── templates/            # プロジェクトテンプレート
└── common/               # 共通設定
```

## 📚 ドキュメント

- [セットアップガイド](docs/setup.md)
- [使用方法](docs/usage.md)
- [アーキテクチャ](docs/architecture/overview.md)

## 🛠️ 利用可能なモジュール

- API Gateway
- CloudFront
- DynamoDB
- Lambda
- S3
- SQS/SNS
- Step Functions
- EventBridge

## ⚡ エイリアス

```bash
tffirst  # fmt + init + plan
tfplan   # fmt + plan
tfapply  # fmt + apply
```