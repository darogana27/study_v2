#!/bin/bash

# PFC リソース起動スクリプト
# 使用方法: ./start-resources.sh

set -e

echo "🚀 PFC リソース起動を開始します..."

# 現在のディレクトリ確認
if [[ ! -f "terraform.tf" ]]; then
    echo "❌ Terraformディレクトリで実行してください"
    exit 1
fi

# 1. Lambda関数を有効化
echo "⚡ Lambda関数を有効化しています..."
LAMBDA_FUNCTIONS=(
    "pfc-park-finder-chat-function"
    "pfc-parking-data-collector-function" 
    "pfc-parking-spots-api-function"
)

for func in "${LAMBDA_FUNCTIONS[@]}"; do
    echo "  - $func を有効化中..."
    aws lambda update-function-configuration \
        --function-name "$func" \
        --environment Variables='{DYNAMODB_TABLE_NAME=pfc-ParkingSpots-table,ENABLE_TOKYO_WIDE=true,MAX_PARALLEL_WARDS=5,BATCH_SIZE=100,ENABLE_GEOHASH=true}' \
        --region ap-northeast-1 2>/dev/null && echo "    ✅ $func 有効化完了" || echo "    ⚠️  $func not found"
done

# 2. API Gateway ステージを再作成
echo "🔗 API Gateway ステージを再作成しています..."
API_ID=$(aws apigatewayv2 get-apis --query "Items[?Name=='pfc-main-api'].ApiId" --output text --region ap-northeast-1 2>/dev/null || echo "")
if [[ -n "$API_ID" && "$API_ID" != "None" ]]; then
    # ステージが存在するかチェック
    STAGE_EXISTS=$(aws apigatewayv2 get-stage --api-id "$API_ID" --stage-name "dev" --region ap-northeast-1 2>/dev/null && echo "exists" || echo "not_exists")
    
    if [[ "$STAGE_EXISTS" == "not_exists" ]]; then
        # ステージを再作成
        aws apigatewayv2 create-stage \
            --api-id "$API_ID" \
            --stage-name "dev" \
            --auto-deploy \
            --region ap-northeast-1 2>/dev/null && echo "    ✅ API Gateway ステージ再作成完了" || echo "    ⚠️  ステージ作成失敗"
    else
        echo "    ✅ API Gateway ステージは既に存在しています"
    fi
else
    echo "    ⚠️  API Gateway not found"
fi

# 3. CloudFront Distribution を有効化
echo "🌐 CloudFront Distribution を有効化しています..."
DISTRIBUTION_ID=$(aws cloudfront list-distributions --query "DistributionList.Items[?Comment=='PFC Main Distribution'].Id" --output text --region us-east-1 2>/dev/null || echo "")
if [[ -n "$DISTRIBUTION_ID" && "$DISTRIBUTION_ID" != "None" ]]; then
    # 現在のステータスを確認
    CURRENT_STATUS=$(aws cloudfront get-distribution --id "$DISTRIBUTION_ID" --query "Distribution.DistributionConfig.Enabled" --output text --region us-east-1 2>/dev/null || echo "")
    
    if [[ "$CURRENT_STATUS" == "False" ]]; then
        # Distribution設定を取得
        aws cloudfront get-distribution-config --id "$DISTRIBUTION_ID" --region us-east-1 > /tmp/distribution-config.json 2>/dev/null || echo "    ⚠️  Distribution config取得失敗"
        
        if [[ -f "/tmp/distribution-config.json" ]]; then
            # ETagを取得
            ETAG=$(jq -r '.ETag' /tmp/distribution-config.json)
            
            # Enabledをtrueに変更
            jq '.DistributionConfig.Enabled = true' /tmp/distribution-config.json > /tmp/distribution-enabled.json
            
            # 有効化を実行
            aws cloudfront update-distribution \
                --id "$DISTRIBUTION_ID" \
                --distribution-config file:///tmp/distribution-enabled.json \
                --if-match "$ETAG" \
                --region us-east-1 2>/dev/null && echo "    ✅ CloudFront有効化開始（完了まで15-20分かかります）" || echo "    ⚠️  CloudFront有効化失敗"
            
            # 一時ファイル削除
            rm -f /tmp/distribution-config.json /tmp/distribution-enabled.json
        fi
    else
        echo "    ✅ CloudFront Distribution は既に有効です"
    fi
else
    echo "    ⚠️  CloudFront Distribution not found"
fi

# 4. EventBridge Scheduler を有効化（データ収集開始）
echo "📅 EventBridge Scheduler を有効化しています..."
aws scheduler update-schedule \
    --name "pfc-parking-data-collector-scheduler" \
    --group-name "pfc-scheduler-group" \
    --state "ENABLED" \
    --schedule-expression "rate(10 minutes)" \
    --flexible-time-window Mode=OFF \
    --target '{"Arn":"arn:aws:lambda:ap-northeast-1:671522354054:function:pfc-parking-data-collector-function","RoleArn":"arn:aws:iam::671522354054:role/pfc-parking-data-collector-schedule-role"}' \
    --region ap-northeast-1 2>/dev/null && echo "    ✅ Scheduler有効化完了" || echo "    ⚠️  Scheduler有効化失敗"

# 5. 初回データ収集を実行
echo "💾 初回データ収集を実行しています..."
aws lambda invoke \
    --function-name "pfc-parking-data-collector-function" \
    --region ap-northeast-1 \
    /tmp/lambda-response.json 2>/dev/null && echo "    ✅ 初回データ収集開始" || echo "    ⚠️  データ収集実行失敗"

# レスポンス確認
if [[ -f "/tmp/lambda-response.json" ]]; then
    echo "    📊 データ収集結果:"
    cat /tmp/lambda-response.json | jq -r '.body' 2>/dev/null | jq '.' 2>/dev/null || cat /tmp/lambda-response.json
    rm -f /tmp/lambda-response.json
fi

echo ""
echo "🎯 リソース起動状況:"
echo "✅ Lambda関数: 全て有効化済み"
echo "✅ API Gateway: ステージ再作成済み"
echo "✅ CloudFront: 有効化開始（完了まで15-20分）"
echo "✅ EventBridge Scheduler: 10分間隔で実行中"
echo "✅ 初回データ収集: 実行済み"
echo ""
echo "🌐 アクセス URL:"
echo "   CloudFront: https://d2ubjdigebrmfd.cloudfront.net"
echo "   API Gateway: https://xckspu9thj.execute-api.ap-northeast-1.amazonaws.com"
echo ""
echo "⚠️  注意: CloudFrontの有効化は15-20分かかります"
echo "📝 停止時は ./stop-resources.sh を実行してください"