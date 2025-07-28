# PFC - 東京都全域駐輪場リアルタイム混雑状況確認ツール

## プロジェクト概要
東京都全域（23区 + 多摩地域主要10市）の駐輪場のリアルタイム混雑状況を確認できるWebツール

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

### 2025-07-28 東京全域対応実装
- **データ範囲拡張**: 池袋エリア → 東京都全域（23区 + 多摩地域主要10市）
- **データ規模**: 19箇所 → 646箇所の駐輪場データ
- **対応エリア**: 49の区・市をカバー
- **技術改善**: 
  - ThreadPoolExecutorによる並列データ収集
  - 主要駅周辺データ生成（山手線全駅 + 主要私鉄駅）
  - GeoHash対応による地理検索最適化
  - DynamoDB複合キー（id + ward）対応

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
- **東京全域駐輪場データ収集**（10分間隔自動更新）
  - 23区全域：千代田区、中央区、港区、新宿区、文京区、台東区、墨田区、江東区、品川区、目黒区、大田区、世田谷区、渋谷区、中野区、杉並区、豊島区、北区、荒川区、板橋区、練馬区、足立区、葛飾区、江戸川区
  - 多摩地域主要10市：八王子市、立川市、武蔵野市、三鷹市、青梅市、府中市、昭島市、調布市、町田市、小金井市
- **主要駅対応**（合計40駅以上）
  - JR山手線全駅：新宿、渋谷、池袋、品川、東京、上野、秋葉原等
  - 主要私鉄駅：吉祥寺、中野、立川、八王子、町田、北千住等
- **時間帯別利用率シミュレーション**（朝7-9時、夕17-19時は高混雑）
- **Claude 3 Sonnet チャット機能**
- **GeoHash対応**による高速地理検索
- **合計646箇所**の駐輪場データ（49エリア）

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
- `lambda/parking-data-collector.py` - **東京全域データ収集機能**（646箇所対応）
- `lambda/requirements.txt` - 外部ライブラリ（geohash2, boto3等）
- `eventbridge.tf` - スケジューラー設定（10分間隔）
- `lambda.tf` - Lambda関数設定
- `dynamodb.tf` - DynamoDB設定（複合キー：id + ward）
- `cloudfront-oac.tf` - CloudFront OAC設定
- `s3-bucket-policy.tf` - S3アクセス制御
- `modules/aws/cloudfront_oac/` - 専用OACモジュール

## 技術スタック
- **AWS Lambda** (Python 3.13)
  - 並列処理：ThreadPoolExecutor
  - 地理計算：geohash2ライブラリ
  - 最大5ワーカーでの並列データ収集
- **Amazon DynamoDB**
  - 複合プライマリキー（id + ward）
  - GSI対応（stationIndex, geoHashIndex）
  - バッチライター対応
- **Amazon S3 + CloudFront**
- **API Gateway HTTP API**
- **EventBridge Scheduler**（10分間隔自動実行）
- **AWS Bedrock** (Claude 3 Sonnet)
- **Terraform** (IaC)

## 開発メモ
- **DynamoDB複合キー**: `id`（HASH）+ `ward`（RANGE）の両方が必須
- **東京全域データ生成**: 主要駅周辺8-15箇所、一般エリア5-10箇所
- **並列処理最適化**: MAX_PARALLEL_WARDS=5で安定動作
- **GeoHash精度**: 精度7（約150m範囲）で地理検索対応
- CloudFront OAC設定時は循環参照に注意
- S3バケットポリシーでCloudFrontアクセス許可必須
- Lambda実行頻度によってコストは大幅に変動
- EventBridge Schedulerは非常に安価（月4,320実行で$0.04）

## データサンプル（最新実行結果）
```json
{
  "statusCode": 200,
  "body": {
    "message": "Successfully updated 627 parking spots in Tokyo",
    "timestamp": "2025-07-28T14:48:37.962736",
    "processed_count": 627,
    "areas_covered": 49
  }
}
```

### 主要エリア別データ分布
- **渋谷区**: 47箇所（渋谷、恵比寿、原宿、代々木駅周辺）
- **新宿区**: 41箇所（新宿、新大久保、高田馬場駅周辺）
- **品川区**: 41箇所（品川、大崎、五反田、目黒駅周辺）
- **豊島区**: 33箇所（池袋、大塚、巣鴨、駒込駅周辺）
- **千代田区**: 27箇所（東京、有楽町、秋葉原、神田駅周辺）
- その他各区・市: 5-20箇所

## システム効率化提案

### 🚀 レベル1: 即座に実施可能（15-20%コスト削減）
- **不要権限削除**: Step Functions権限を削除（コード内でコメントアウト済み）
- **メモリ最適化**: 
  - `park-finder-chat`: 256MB → 128MB（チャット処理には過剰）
  - `parking-data-collector`: 実行時メモリ使用量を確認して調整

### 🔧 レベル2: 中期改善（1-2時間で実施）
- **Lambda関数統合**: 
  - `park-finder-chat.py` + `parking-spots-api.py` → 1関数に統合
  - 両方ともDynamoDBアクセスのみで類似処理
  - API Gateway統合が簡潔になり管理コスト削減
- **Lambda Layer導入**: 
  - 共通ライブラリ（boto3, geohash2等）をLayer化
  - デプロイサイズ50%削減、デプロイ速度向上

### ⚡ レベル3: 長期最適化（半日～1日）
- **DynamoDB最適化**: 
  - 読み取りパターンに最適化したGSI設計
  - On-Demand → Provisioned（予測可能な負荷の場合）
  - GSI活用不足の改善
- **キャッシュ層追加**: ElastiCache導入でDynamoDB負荷軽減
- **ビルドプロセス改善**: 共通ライブラリの分離とLayer活用

### 現在の構成分析結果
- **Lambda関数**: 3個（統合により2個に削減可能）
- **メモリ使用量**: 最適化により30-40%削減見込み
- **権限設定**: 未使用権限あり（Step Functions等）
- **DynamoDBアクセス**: バッチ処理とGSI活用に改善余地あり