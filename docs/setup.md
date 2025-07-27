# セットアップガイド

## 前提条件

- AWS CLI設定済み
- Terraform >= 1.0
- make コマンド使用可能

## 初回セットアップ

### 1. バックエンドインフラの作成

```bash
cd backend
terraform init
terraform plan
terraform apply
```

出力されたS3バケット名をメモしておく：
```bash
terraform output s3_bucket_name
```

### 2. make-productコマンドの準備

```bash
# スクリプトが ~/bin にインストール済みの場合
make-product -name test-project

# 初回の場合は手動でbackend.tfを更新
cd product/test-project
# backend.tfのYOUR_S3_BUCKET_NAMEを実際のバケット名に置き換え
```

## プロジェクト作成フロー

1. **新規プロジェクト作成**
   ```bash
   make-product -name my-project -region ap-northeast-1
   ```

2. **バックエンド設定の更新**
   ```bash
   cd github/study_v2/product/my-project
   # backend.tfのバケット名を更新
   ```

3. **Terraform実行**
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```