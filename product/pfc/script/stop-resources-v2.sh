#!/bin/bash

# PFC リソース停止スクリプト (タグベース版)
# 使用方法: ./stop-resources-v2.sh

set -e

echo "🛑 PFC リソース停止を開始します..."

# 現在のディレクトリ確認
if [[ ! -f "terraform.tf" ]]; then
    echo "❌ Terraformディレクトリで実行してください"
    exit 1
fi

# タグ設定
PRODUCT_TAG="pfc"
REGION="ap-northeast-1"

# 1. EventBridge Scheduler を無効化（タグベース検出）
echo "📅 EventBridge Scheduler を無効化しています..."
SCHEDULER_ARNS=$(aws resourcegroupstaggingapi get-resources \
    --tag-filters "Key=Product,Values=$PRODUCT_TAG" \
    --resource-type-filters "scheduler:schedule" \
    --region $REGION \
    --query "ResourceTagMappingList[].ResourceARN" \
    --output text 2>/dev/null || echo "")

if [[ -n "$SCHEDULER_ARNS" ]]; then
    for arn in $SCHEDULER_ARNS; do
        # ARNからスケジュール名とグループ名を抽出
        # arn:aws:scheduler:region:account:schedule/group-name/schedule-name
        GROUP_NAME=$(echo $arn | cut -d'/' -f2)
        SCHEDULE_NAME=$(echo $arn | cut -d'/' -f3)
        
        echo "  - $SCHEDULE_NAME を無効化中..."
        
        # 現在の設定を取得
        CURRENT_CONFIG=$(aws scheduler get-schedule \
            --name "$SCHEDULE_NAME" \
            --group-name "$GROUP_NAME" \
            --region $REGION 2>/dev/null || echo "")
        
        if [[ -n "$CURRENT_CONFIG" ]]; then
            # 必要な設定を抽出
            SCHEDULE_EXPR=$(echo "$CURRENT_CONFIG" | jq -r '.ScheduleExpression')
            FLEXIBLE_TIME=$(echo "$CURRENT_CONFIG" | jq -r '.FlexibleTimeWindow')
            TARGET_CONFIG=$(echo "$CURRENT_CONFIG" | jq -r '.Target')
            
            # スケジュールを無効化
            aws scheduler update-schedule \
                --name "$SCHEDULE_NAME" \
                --group-name "$GROUP_NAME" \
                --state "DISABLED" \
                --schedule-expression "$SCHEDULE_EXPR" \
                --flexible-time-window "$FLEXIBLE_TIME" \
                --target "$TARGET_CONFIG" \
                --region $REGION 2>/dev/null && echo "    ✅ $SCHEDULE_NAME 無効化完了" || echo "    ⚠️  $SCHEDULE_NAME 無効化失敗"
        fi
    done
else
    echo "    ⚠️  PFC Scheduler not found"
fi

# 2. Lambda関数を無効化（タグベース検出）
echo "⚡ Lambda関数を無効化しています..."
LAMBDA_ARNS=$(aws resourcegroupstaggingapi get-resources \
    --tag-filters "Key=Product,Values=$PRODUCT_TAG" \
    --resource-type-filters "lambda:function" \
    --region $REGION \
    --query "ResourceTagMappingList[].ResourceARN" \
    --output text 2>/dev/null || echo "")

if [[ -n "$LAMBDA_ARNS" ]]; then
    for arn in $LAMBDA_ARNS; do
        # ARNから関数名を抽出
        FUNCTION_NAME=$(echo $arn | cut -d':' -f7)
        
        echo "  - $FUNCTION_NAME を無効化中..."
        aws lambda update-function-configuration \
            --function-name "$FUNCTION_NAME" \
            --environment Variables='{DISABLED=true}' \
            --region $REGION 2>/dev/null && echo "    ✅ $FUNCTION_NAME 無効化完了" || echo "    ⚠️  $FUNCTION_NAME 無効化失敗"
    done
else
    echo "    ⚠️  PFC Lambda functions not found"
fi

# 3. CloudFront Distribution を無効化（タグベース検出）
echo "🌐 CloudFront Distribution を無効化しています..."
CLOUDFRONT_ARNS=$(aws resourcegroupstaggingapi get-resources \
    --tag-filters "Key=Product,Values=$PRODUCT_TAG" \
    --resource-type-filters "cloudfront:distribution" \
    --region us-east-1 \
    --query "ResourceTagMappingList[].ResourceARN" \
    --output text 2>/dev/null || echo "")

if [[ -n "$CLOUDFRONT_ARNS" ]]; then
    for arn in $CLOUDFRONT_ARNS; do
        # ARNからDistribution IDを抽出
        DISTRIBUTION_ID=$(echo $arn | cut -d'/' -f2)
        
        echo "  - Distribution $DISTRIBUTION_ID を無効化中..."
        
        # 現在のステータスを確認
        CURRENT_STATUS=$(aws cloudfront get-distribution \
            --id "$DISTRIBUTION_ID" \
            --query "Distribution.DistributionConfig.Enabled" \
            --output text \
            --region us-east-1 2>/dev/null || echo "")
        
        if [[ "$CURRENT_STATUS" == "True" ]]; then
            # Distribution設定を取得
            aws cloudfront get-distribution-config \
                --id "$DISTRIBUTION_ID" \
                --region us-east-1 > /tmp/distribution-config.json 2>/dev/null || continue
            
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
                    --region us-east-1 2>/dev/null && echo "    ✅ CloudFront無効化開始（完了まで15-20分）" || echo "    ⚠️  CloudFront無効化失敗"
                
                # 一時ファイル削除
                rm -f /tmp/distribution-config.json /tmp/distribution-disabled.json
            fi
        else
            echo "    ℹ️  Distribution $DISTRIBUTION_ID は既に無効です"
        fi
    done
else
    echo "    ⚠️  PFC CloudFront Distribution not found"
fi

# 4. DynamoDB テーブルをバックアップ（タグベース検出）
echo "💾 DynamoDB テーブルをバックアップしています..."
DYNAMODB_ARNS=$(aws resourcegroupstaggingapi get-resources \
    --tag-filters "Key=Product,Values=$PRODUCT_TAG" \
    --resource-type-filters "dynamodb:table" \
    --region $REGION \
    --query "ResourceTagMappingList[].ResourceARN" \
    --output text 2>/dev/null || echo "")

if [[ -n "$DYNAMODB_ARNS" ]]; then
    for arn in $DYNAMODB_ARNS; do
        # ARNからテーブル名を抽出
        TABLE_NAME=$(echo $arn | cut -d'/' -f2)
        BACKUP_NAME="$PRODUCT_TAG-backup-$(date +%Y%m%d-%H%M%S)-$TABLE_NAME"
        
        echo "  - $TABLE_NAME をバックアップ中..."
        aws dynamodb create-backup \
            --table-name "$TABLE_NAME" \
            --backup-name "$BACKUP_NAME" \
            --region $REGION 2>/dev/null && echo "    ✅ バックアップ作成: $BACKUP_NAME" || echo "    ⚠️  バックアップ作成失敗"
    done
else
    echo "    ⚠️  PFC DynamoDB tables not found"
fi

# 5. API Gateway のステージを削除（タグベース検出）
echo "🔗 API Gateway ステージを無効化しています..."
API_ARNS=$(aws resourcegroupstaggingapi get-resources \
    --tag-filters "Key=Product,Values=$PRODUCT_TAG" \
    --resource-type-filters "apigateway:restapis,apigateway:apis" \
    --region $REGION \
    --query "ResourceTagMappingList[?contains(ResourceARN, '/stages/')].ResourceARN" \
    --output text 2>/dev/null || echo "")

if [[ -n "$API_ARNS" ]]; then
    for arn in $API_ARNS; do
        # arn:aws:apigateway:region::/apis/api-id/stages/stage-name
        API_ID=$(echo $arn | cut -d'/' -f3)
        STAGE_NAME=$(echo $arn | cut -d'/' -f5)
        
        echo "  - API $API_ID のステージ $STAGE_NAME を削除中..."
        aws apigatewayv2 delete-stage \
            --api-id "$API_ID" \
            --stage-name "$STAGE_NAME" \
            --region $REGION 2>/dev/null && echo "    ✅ ステージ削除完了" || echo "    ⚠️  ステージ削除失敗"
    done
else
    echo "    ⚠️  PFC API Gateway stages not found"
fi

echo ""
echo "🎯 リソース停止状況:"
echo "✅ EventBridge Scheduler: タグベース検出・無効化"
echo "✅ Lambda関数: タグベース検出・DISABLED=true設定"
echo "✅ CloudFront: タグベース検出・無効化開始"
echo "✅ DynamoDB: タグベース検出・バックアップ作成"
echo "✅ API Gateway: タグベース検出・ステージ削除"
echo ""
echo "💡 コスト削減効果:"
echo "   - Lambda実行コスト: ほぼ0円"
echo "   - CloudFront転送コスト: 0円" 
echo "   - API Gateway実行コスト: 0円"
echo "   - DynamoDB: ストレージ費用のみ（約$0.25/月）"
echo ""
echo "⚠️  注意: CloudFrontの無効化は15-20分かかります"
echo "📝 再起動時は ./start-resources-v2.sh を実行してください"