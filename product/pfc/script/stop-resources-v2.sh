#!/bin/bash

# PFC リソース停止スクリプト (タグベース版)
# 使用方法: ./stop-resources-v2.sh

set -e

echo "🛑 PFC リソース停止を開始します..."

# 現在のディレクトリ確認とinfrastructureディレクトリへの移動
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
INFRASTRUCTURE_DIR="$PROJECT_ROOT/infrastructure"

if [[ ! -f "$INFRASTRUCTURE_DIR/terraform.tf" ]]; then
    echo "❌ infrastructure/terraform.tf が見つかりません"
    echo "プロジェクトルートから実行してください"
    exit 1
fi

echo "📁 作業ディレクトリ: $INFRASTRUCTURE_DIR"

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
    # フォールバック: 直接Scheduler名で検索
    echo "    🔄 フォールバック: 直接Scheduler検索中..."
    SCHEDULES=$(aws scheduler list-schedules --group-name "pfc-scheduler-group" --region $REGION --query "Schedules[?contains(Name,'pfc')].{Name:Name,State:State}" --output text 2>/dev/null || echo "")
    
    if [[ -n "$SCHEDULES" ]]; then
        echo "$SCHEDULES" | while read -r name state; do
            if [[ -n "$name" ]]; then
                echo "  - $name を無効化中..."
                
                # 現在の設定を取得
                CURRENT_CONFIG=$(aws scheduler get-schedule \
                    --name "$name" \
                    --group-name "pfc-scheduler-group" \
                    --region $REGION 2>/dev/null || echo "")
                
                if [[ -n "$CURRENT_CONFIG" ]]; then
                    # 必要な設定を抽出
                    SCHEDULE_EXPR=$(echo "$CURRENT_CONFIG" | jq -r '.ScheduleExpression')
                    FLEXIBLE_TIME=$(echo "$CURRENT_CONFIG" | jq -r '.FlexibleTimeWindow')
                    TARGET_CONFIG=$(echo "$CURRENT_CONFIG" | jq -r '.Target')
                    
                    # スケジュールを無効化
                    aws scheduler update-schedule \
                        --name "$name" \
                        --group-name "pfc-scheduler-group" \
                        --state "DISABLED" \
                        --schedule-expression "$SCHEDULE_EXPR" \
                        --flexible-time-window "$FLEXIBLE_TIME" \
                        --target "$TARGET_CONFIG" \
                        --region $REGION 2>/dev/null && echo "    ✅ $name 無効化完了" || echo "    ⚠️  $name 無効化失敗"
                fi
            fi
        done
    else
        echo "    ⚠️  PFC Scheduler not found"
    fi
fi

# 2. Lambda関数は停止しない（実行されても最小コスト）
echo "⚡ Lambda関数は停止せず（実行時のみ課金のため）"

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
            # Distribution設定を取得してETagを保存
            ETAG=$(aws cloudfront get-distribution-config \
                --id "$DISTRIBUTION_ID" \
                --region us-east-1 \
                --query "ETag" \
                --output text 2>/dev/null || echo "")
            
            # Distribution設定をJSONファイルに保存
            CONFIG_JSON=$(aws cloudfront get-distribution-config \
                --id "$DISTRIBUTION_ID" \
                --region us-east-1 \
                --query "DistributionConfig" 2>/dev/null || echo "")
            
            if [[ -n "$ETAG" && -n "$CONFIG_JSON" ]]; then
                echo "$CONFIG_JSON" | jq '.Enabled = false' > /tmp/distribution-disabled.json
                
                # 無効化を実行
                aws cloudfront update-distribution \
                    --id "$DISTRIBUTION_ID" \
                    --distribution-config file:///tmp/distribution-disabled.json \
                    --if-match "$ETAG" \
                    --region us-east-1 2>/dev/null && echo "    ✅ CloudFront無効化開始（完了まで15-20分）" || echo "    ⚠️  CloudFront無効化失敗"
                
                # 一時ファイル削除
                rm -f /tmp/distribution-disabled.json
            else
                echo "    ⚠️  CloudFront設定の取得に失敗"
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
    # フォールバック: 直接API名で検索
    echo "    🔄 フォールバック: 直接API検索中..."
    API_ID=$(aws apigatewayv2 get-apis --query "Items[?contains(Name,'pfc')].ApiId" --output text --region $REGION 2>/dev/null || echo "")
    if [[ -n "$API_ID" && "$API_ID" != "None" ]]; then
        echo "  - API $API_ID のステージ dev を削除中..."
        aws apigatewayv2 delete-stage \
            --api-id "$API_ID" \
            --stage-name "dev" \
            --region $REGION 2>/dev/null && echo "    ✅ ステージ削除完了" || echo "    ⚠️  ステージ削除失敗"
    else
        echo "    ⚠️  PFC API Gateway stages not found"
    fi
fi

echo ""
echo "🎯 リソース停止状況:"
echo "✅ EventBridge Scheduler: タグベース検出・無効化"
echo "✅ Lambda関数: 停止なし（実行時のみ課金）"
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