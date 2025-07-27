# PFC (Parking Finder Chat) システム構成図

## 全体アーキテクチャ概要

```mermaid
graph TB
    %% ユーザー層
    U[ユーザー] --> WEB[Webアプリケーション<br/>React + Leaflet Map]
    
    %% フロントエンド層
    WEB --> CF[CloudFront<br/>CDN配信]
    CF --> S3[S3 Bucket<br/>静的ホスティング]
    
    %% API層
    WEB --> AGW[API Gateway<br/>HTTP API]
    AGW --> LF1[Lambda Function<br/>park-finder-chat<br/>256MB / 30sec]
    AGW --> LF2[Lambda Function<br/>parking-spots-api<br/>128MB / 30sec]
    
    %% AI/チャット処理
    LF1 --> BR[Amazon Bedrock<br/>Claude-3-Haiku<br/>コスト最適化済み]
    
    %% データ層
    LF1 --> DDB[DynamoDB<br/>ParkingSpots Table<br/>Pay-per-Request]
    LF2 --> DDB
    
    %% データ収集
    EB[EventBridge Scheduler<br/>10分間隔] --> LF3[Lambda Function<br/>parking-data-collector<br/>128MB / 60sec]
    LF3 --> DDB
    LF3 --> EXT[外部駐車場API<br/>データ収集]
    
    %% 監視・ログ
    LF1 --> CW[CloudWatch Logs]
    LF2 --> CW
    LF3 --> CW
    
    classDef frontend fill:#e1f5fe
    classDef api fill:#f3e5f5
    classDef ai fill:#fff3e0
    classDef data fill:#e8f5e8
    classDef schedule fill:#fce4ec
    classDef monitor fill:#f1f8e9
    
    class WEB,CF,S3 frontend
    class AGW,LF1,LF2 api
    class BR ai
    class DDB data
    class EB,LF3,EXT schedule
    class CW monitor
```

## 選択肢型チャットフロー

```mermaid
sequenceDiagram
    participant U as ユーザー
    participant F as フロントエンド
    participant A as API Gateway
    participant L as Lambda (Chat)
    participant D as DynamoDB
    participant B as Bedrock

    Note over U,B: 選択肢モード（コスト最適化）
    
    U->>F: 1. 場所を選択（🌳公園 / 🚉駅周辺 / 🛒商業施設）
    F->>F: ローカル処理
    
    U->>F: 2. 優先条件選択（💰無料 / 🚶駅近 / 🏍️バイク可）
    F->>F: ローカル処理
    
    U->>F: 3. エリア選択（池袋西口 / 東口 / 現在地）
    F->>A: API呼び出し（選択情報）
    A->>L: 選択情報処理
    
    L->>L: フィルタ条件構築
    L->>D: 事前フィルタリング（最大10件）
    D-->>L: フィルタ済みデータ
    
    L->>B: 超短縮プロンプト<br/>（150トークン制限）
    B-->>L: 最適化された応答
    
    L-->>A: 結果 + 推奨駐車場
    A-->>F: レスポンス
    F->>U: 結果表示 + マップ更新

    Note over U,B: フリー入力モード（従来）
    
    U->>F: 自然言語入力
    F->>A: テキストメッセージ
    A->>L: フォールバック処理
    L->>D: 全データ取得
    L-->>F: キーワードベース応答
```

## コスト最適化戦略

```mermaid
graph LR
    subgraph "従来方式"
        T1[自然言語入力] --> T2[全データ送信<br/>1000トークン]
        T2 --> T3[Claude-3-Sonnet<br/>$48/1M出力トークン]
        T3 --> T4[月額: $10.80]
    end
    
    subgraph "選択肢型最適化"
        O1[3段階選択] --> O2[事前フィルタリング<br/>150トークン]
        O2 --> O3[Claude-3-Haiku<br/>$12/1M出力トークン]
        O3 --> O4[月額: $1.20]
    end
    
    T4 -.->|89%削減| O4
    
    classDef old fill:#ffcdd2
    classDef new fill:#c8e6c9
    
    class T1,T2,T3,T4 old
    class O1,O2,O3,O4 new
```

## インフラリソース詳細

### コンピュート
- **Lambda Functions**: 3個
  - `park-finder-chat`: 256MB, 30sec (選択肢処理 + Bedrock連携)
  - `parking-spots-api`: 128MB, 30sec (データ取得API)
  - `parking-data-collector`: 128MB, 60sec (データ収集)

### ストレージ
- **DynamoDB**: Pay-per-Request, 1テーブル
- **S3**: 静的サイトホスティング, ライフサイクル設定

### ネットワーク
- **API Gateway**: HTTP API, CORS設定
- **CloudFront**: PriceClass_100, 地域制限（JP/US）

### AI/ML
- **Amazon Bedrock**: Claude-3-Haiku, トークン制限設定

### スケジュール
- **EventBridge Scheduler**: 10分間隔実行

## 月額料金見積もり（月1000アクセス時）

| サービス | 月額料金 (USD) | 備考 |
|----------|----------------|------|
| **Lambda実行** | $1.21 | 3関数合計 |
| **DynamoDB** | $0.67 | オンデマンド |
| **API Gateway** | $0.001 | 1000リクエスト |
| **Bedrock (最適化後)** | $1.20 | **89%削減達成** |
| **CloudFront** | $0.085 | 10MB転送 |
| **S3** | $0.023 | 1GBストレージ |
| **EventBridge** | $0.004 | 4,320実行/月 |
| **CloudWatch** | $0.50 | ログ保存 |
| **合計** | **$3.76** | **約¥560** |

## セキュリティ設定

### IAM権限
- Lambda実行ロール: 最小権限原則
- DynamoDB: 必要テーブルのみアクセス
- Bedrock: 特定モデルのみ実行権限

### ネットワーク
- CloudFront: 地域制限（日本・アメリカ）
- API Gateway: CORS設定
- S3: パブリックアクセス制限

### データ保護
- DynamoDB: 保存時暗号化
- CloudWatch: ログ保持期間設定
- Bedrock: トークン制限によるコスト保護

## 監視・運用

### メトリクス
- Lambda: 実行回数、エラー率、レスポンス時間
- DynamoDB: 読み書きスループット、スロットリング
- Bedrock: トークン使用量、コスト追跡

### アラート
- Lambda実行エラー
- DynamoDBスロットリング
- Bedrockコスト上限

### ログ
- アプリケーションログ（CloudWatch Logs）
- アクセスログ（CloudFront）
- API実行ログ（API Gateway）

## デプロイメント

### Terraform管理リソース
```
infrastructure/
├── apigateway.tf     # API Gateway設定
├── cloudfront.tf     # CDN設定
├── dynamodb.tf       # データベース
├── eventbridge.tf    # スケジューラー
├── lambda.tf         # 関数定義
├── locals.tf         # 共通設定
├── s3.tf            # ストレージ
└── terraform.tf     # プロバイダー設定
```

### 環境変数設定
- `ENABLE_SELECTION_MODE`: 選択肢モード有効化
- `MAX_BEDROCK_TOKENS`: トークン上限（150）
- `BEDROCK_MODEL_ID`: Claude-3-Haiku指定

## パフォーマンス最適化

### フロントエンド
- React Hooks最適化
- レスポンシブデザイン
- 地図表示最適化（Leaflet）

### バックエンド
- DynamoDB事前フィルタリング
- Lambda冷却時間短縮
- Bedrockプロンプト最適化

### コスト最適化
- 選択肢型UI導入（89%削減）
- Haikuモデル採用（60%安価）
- トークン制限実装
- 事前フィルタリング戦略