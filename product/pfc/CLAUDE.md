# PFC - 駐輪場リアルタイム混雑状況確認ツール

## プロジェクト概要
池袋エリアの駐輪場のリアルタイム混雑状況を確認できるWebツール

## 開発履歴

### 2025-07-21 初期開発
- 基本的なAWSインフラ設計
- Lambda、DynamoDB、S3、CloudFront、API Gateway構成
- 軽量構成選択（月額約$20想定）

### 2025-07-25 CloudFront問題解決
- **問題**: CloudFrontアクセス拒否エラー（AccessDenied）
- **原因**: S3バケットポリシーとOAC設定の問題
- **解決**: 
  - 専用CloudFront OACモジュール作成（`/modules/aws/cloudfront_oac/`）
  - S3バケットポリシー追加（`s3-bucket-policy.tf`）
  - Terraform循環参照問題解決

### 2025-07-26 料金再計算
- **前回想定**: 月額$20
- **実際計算**: 月額$0.80（約¥120）
- **主要コスト**: DynamoDB($0.30) + CloudWatch Logs($0.10) + Lambda($0.20)

## 現在の構成

### AWSリソース (36個稼働中)
- **Lambda関数**: 2個
  - `park-finder-chat` (256MB, 手動実行)
  - `parking-data-collector` (128MB, 10分間隔実行)
- **DynamoDB**: ParkingSpots テーブル
- **S3**: HTMLファイル配信用
- **CloudFront**: 高速配信（https://d2ubjdigebrmfd.cloudfront.net）
- **API Gateway**: RESTful API（https://xckspu9thj.execute-api.ap-northeast-1.amazonaws.com）
- **EventBridge Scheduler**: 10分間隔データ収集
- **CloudWatch**: ログ管理

### 機能
- リアルタイム駐輪場データ収集（10分間隔）
- 時間帯別利用率シミュレーション（朝7-9時、夕17-19時は高混雑）
- Claude 3 Sonnet チャット機能
- 池袋エリア5ヶ所の駐輪場データ

### 開発コマンド
```bash
# Terraform操作
terraform plan
terraform apply -auto-approve

# テスト
curl -I https://d2ubjdigebrmfd.cloudfront.net
```

### ファイル構成
- `lambda/park-finder-chat.py` - チャット機能
- `lambda/parking-data-collector.py` - データ収集機能  
- `eventbridge.tf` - スケジューラー設定
- `lambda.tf` - Lambda関数設定
- `cloudfront-oac.tf` - CloudFront OAC設定
- `s3-bucket-policy.tf` - S3アクセス制御
- `modules/aws/cloudfront_oac/` - 専用OACモジュール

## 技術スタック
- AWS Lambda (Python 3.13)
- Amazon DynamoDB
- Amazon S3 + CloudFront
- API Gateway HTTP API
- EventBridge Scheduler
- AWS Bedrock (Claude 3 Sonnet)
- Terraform (IaC)

## 開発メモ
- CloudFront OAC設定時は循環参照に注意
- S3バケットポリシーでCloudFrontアクセス許可必須
- Lambda実行頻度によってコストは大幅に変動
- EventBridge Schedulerは非常に安価（月4,320実行で$0.04）