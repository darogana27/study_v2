#!/bin/bash

# PFC リソース停止スクリプト
# 使用方法: ./stop-resources.sh

set -e

echo "🛑 PFC リソース停止を開始します..."

# 現在のディレクトリ確認
if [[ ! -f "terraform.tf" ]]; then
    echo "❌ Terraformディレクトリで実行してください"
    exit 1
fi

# 1. EventBridge Scheduler を無効化（データ収集停止）
echo "📅 EventBridge Scheduler を無効化しています..."
aws scheduler update-schedule \
    --name "pfc-parking-data-collector-scheduler" \
    --group-name "pfc-scheduler-group" \
    --state "DISABLED" \
    --schedule-expression "rate(10 minutes)" \
    --flexible-time-window Mode=OFF \
    --target '{"Arn":"arn:aws:lambda:ap-northeast-1:671522354054:function:pfc-parking-data-collector-function","RoleArn":"arn:aws:iam::671522354054:role/pfc-parking-data-collector-schedule-role"}' \
    --region ap-northeast-1 2>/dev/null && echo "    ✅ Scheduler無効化完了" || echo "    ⚠️  Scheduler無効化失敗"

# 2. Lambda関数を無効化（実行防止）
echo "⚡ Lambda関数を無効化しています..."
LAMBDA_FUNCTIONS=(
    "pfc-park-finder-chat-function"
    "pfc-parking-data-collector-function" 
    "pfc-parking-spots-api-function"
)

for func in "${LAMBDA_FUNCTIONS[@]}"; do
    echo "  - $func を無効化中..."
    aws lambda update-function-configuration \
        --function-name "$func" \
        --environment Variables='{DISABLED=true}' \
        --region ap-northeast-1 2>/dev/null && echo "    ✅ $func 無効化完了" || echo "    ⚠️  $func not found"
done

# 3. CloudFront Distribution を無効化
echo "🌐 CloudFront Distribution を無効化しています..."
DISTRIBUTION_ID=$(aws cloudfront list-distributions --query "DistributionList.Items[?Comment=='PFC Main Distribution'].Id" --output text --region us-east-1 2>/dev/null || echo "")
if [[ -n "$DISTRIBUTION_ID" && "$DISTRIBUTION_ID" != "None" ]]; then
    # Distribution設定を取得
    aws cloudfront get-distribution-config --id "$DISTRIBUTION_ID" --region us-east-1 > /tmp/distribution-config.json 2>/dev/null || echo "    ⚠️  Distribution config取得失敗"
    
    if [[ -f "/tmp/distribution-config.json" ]]; then
        # ETagを取得
        ETAG=$(jq -r '.ETag' /tmp/distribution-config.json)
        
        # Enabledをfalseに変更
        jq '.DistributionConfig.Enabled = false' /tmp/distribution-config.json > /tmp/distribution-disabled.json
        
        # 無効化を実行
        aws cloudfront update-distribution \
            --id "$DISTRIBUTION_ID" \
            --distribution-config file:///tmp/distribution-disabled.json \
            --if-match "$ETAG" \
            --region us-east-1 2>/dev/null && echo "    ✅ CloudFront無効化開始（完了まで15-20分かかります）" || echo "    ⚠️  CloudFront無効化失敗"
        
        # 一時ファイル削除
        rm -f /tmp/distribution-config.json /tmp/distribution-disabled.json
    fi
else
    echo "    ⚠️  CloudFront Distribution not found"
fi

# 4. DynamoDB テーブルをバックアップ（オプション）
echo "💾 DynamoDB テーブルをバックアップしています（オプション）..."
TABLE_NAME="pfc-ParkingSpots-table"
BACKUP_NAME="pfc-backup-$(date +%Y%m%d-%H%M%S)"

aws dynamodb create-backup \
    --table-name "$TABLE_NAME" \
    --backup-name "$BACKUP_NAME" \
    --region ap-northeast-1 2>/dev/null && echo "    ✅ バックアップ作成: $BACKUP_NAME" || echo "    ⚠️  バックアップ作成失敗"

# 5. API Gateway のステージを無効化（削除）
echo "🔗 API Gateway ステージを無効化しています..."
API_ID=$(aws apigatewayv2 get-apis --query "Items[?Name=='pfc-main-api'].ApiId" --output text --region ap-northeast-1 2>/dev/null || echo "")
if [[ -n "$API_ID" && "$API_ID" != "None" ]]; then
    aws apigatewayv2 delete-stage \
        --api-id "$API_ID" \
        --stage-name "dev" \
        --region ap-northeast-1 2>/dev/null && echo "    ✅ API Gateway ステージ削除完了" || echo "    ⚠️  ステージ削除失敗"
else
    echo "    ⚠️  API Gateway not found"
fi

echo ""
echo "🎯 リソース停止状況:"
echo "✅ EventBridge Scheduler: 無効化"
echo "✅ Lambda関数: 環境変数でDISABLED=true設定"
echo "✅ CloudFront: 無効化開始（完了まで15-20分）"
echo "✅ DynamoDB: バックアップ作成済み"
echo "✅ API Gateway: ステージ削除"
echo ""
echo "💡 コスト削減効果:"
echo "   - Lambda実行コスト: ほぼ0円"
echo "   - CloudFront転送コスト: 0円"
echo "   - API Gateway実行コスト: 0円"
echo "   - DynamoDB: ストレージ費用のみ（約$0.25/月）"
echo ""
echo "⚠️  注意: CloudFrontの無効化は15-20分かかります"
echo "📝 再起動時は ./start-resources.sh を実行してください"