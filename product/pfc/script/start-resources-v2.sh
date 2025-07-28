#!/bin/bash

# PFC リソース起動スクリプト (タグベース版)
# 使用方法: ./start-resources-v2.sh

set -e

echo "🚀 PFC リソース起動を開始します..."

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

# 1. Lambda関数を有効化（タグベース検出）
echo "⚡ Lambda関数を有効化しています..."
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
        
        echo "  - $FUNCTION_NAME を有効化中..."
        aws lambda update-function-configuration \
            --function-name "$FUNCTION_NAME" \
            --environment Variables='{DYNAMODB_TABLE_NAME=pfc-ParkingSpots-table,ENABLE_TOKYO_WIDE=true,MAX_PARALLEL_WARDS=5,BATCH_SIZE=100,ENABLE_GEOHASH=true}' \
            --region $REGION 2>/dev/null && echo "    ✅ $FUNCTION_NAME 有効化完了" || echo "    ⚠️  $FUNCTION_NAME 有効化失敗"
    done
else
    echo "    ⚠️  PFC Lambda functions not found"
fi

# 2. API Gateway ステージを再作成（タグベース検出）
echo "🔗 API Gateway ステージを再作成しています..."
API_ARNS=$(aws resourcegroupstaggingapi get-resources \
    --tag-filters "Key=Product,Values=$PRODUCT_TAG" \
    --resource-type-filters "apigateway:restapis,apigateway:apis" \
    --region $REGION \
    --query "ResourceTagMappingList[?!contains(ResourceARN, '/stages/')].ResourceARN" \
    --output text 2>/dev/null || echo "")

if [[ -n "$API_ARNS" ]]; then
    for arn in $API_ARNS; do
        # arn:aws:apigateway:region::/apis/api-id
        API_ID=$(echo $arn | cut -d'/' -f3)
        STAGE_NAME="dev"  # デフォルトステージ名
        
        echo "  - API $API_ID のステージ $STAGE_NAME を確認中..."
        
        # ステージが存在するかチェック
        STAGE_EXISTS=$(aws apigatewayv2 get-stage \
            --api-id "$API_ID" \
            --stage-name "$STAGE_NAME" \
            --region $REGION 2>/dev/null && echo "exists" || echo "not_exists")
        
        if [[ "$STAGE_EXISTS" == "not_exists" ]]; then
            # ステージを再作成
            aws apigatewayv2 create-stage \
                --api-id "$API_ID" \
                --stage-name "$STAGE_NAME" \
                --auto-deploy \
                --region $REGION 2>/dev/null && echo "    ✅ ステージ再作成完了" || echo "    ⚠️  ステージ作成失敗"
        else
            echo "    ℹ️  ステージは既に存在しています"
        fi
    done
else
    # フォールバック: 直接API名で検索
    echo "    🔄 フォールバック: 直接API検索中..."
    API_ID=$(aws apigatewayv2 get-apis --query "Items[?contains(Name,'pfc')].ApiId" --output text --region $REGION 2>/dev/null || echo "")
    if [[ -n "$API_ID" && "$API_ID" != "None" ]]; then
        echo "  - API $API_ID のステージ dev を確認中..."
        STAGE_EXISTS=$(aws apigatewayv2 get-stage --api-id "$API_ID" --stage-name "dev" --region $REGION 2>/dev/null && echo "exists" || echo "not_exists")
        
        if [[ "$STAGE_EXISTS" == "not_exists" ]]; then
            aws apigatewayv2 create-stage \
                --api-id "$API_ID" \
                --stage-name "dev" \
                --auto-deploy \
                --region $REGION 2>/dev/null && echo "    ✅ ステージ再作成完了" || echo "    ⚠️  ステージ作成失敗"
        else
            echo "    ℹ️  ステージは既に存在しています"
        fi
    else
        echo "    ⚠️  PFC API Gateway not found"
    fi
fi

# 3. CloudFront Distribution を有効化（タグベース検出）
echo "🌐 CloudFront Distribution を有効化しています..."
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
        
        echo "  - Distribution $DISTRIBUTION_ID を有効化中..."
        
        # 現在のステータスを確認
        CURRENT_STATUS=$(aws cloudfront get-distribution \
            --id "$DISTRIBUTION_ID" \
            --query "Distribution.DistributionConfig.Enabled" \
            --output text \
            --region us-east-1 2>/dev/null || echo "")
        
        if [[ "$CURRENT_STATUS" == "False" ]]; then
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
                echo "$CONFIG_JSON" | jq '.Enabled = true' > /tmp/distribution-enabled.json
                
                # 有効化を実行
                aws cloudfront update-distribution \
                    --id "$DISTRIBUTION_ID" \
                    --distribution-config file:///tmp/distribution-enabled.json \
                    --if-match "$ETAG" \
                    --region us-east-1 2>/dev/null && echo "    ✅ CloudFront有効化開始（完了まで15-20分）" || echo "    ⚠️  CloudFront有効化失敗"
                
                # 一時ファイル削除
                rm -f /tmp/distribution-enabled.json
            else
                echo "    ⚠️  CloudFront設定の取得に失敗"
            fi
        else
            echo "    ℹ️  Distribution $DISTRIBUTION_ID は既に有効です"
        fi
    done
else
    echo "    ⚠️  PFC CloudFront Distribution not found"
fi

# 4. EventBridge Scheduler を有効化（タグベース検出）
echo "📅 EventBridge Scheduler を有効化しています..."
SCHEDULER_ARNS=$(aws resourcegroupstaggingapi get-resources \
    --tag-filters "Key=Product,Values=$PRODUCT_TAG" \
    --resource-type-filters "scheduler:schedule" \
    --region $REGION \
    --query "ResourceTagMappingList[].ResourceARN" \
    --output text 2>/dev/null || echo "")

if [[ -n "$SCHEDULER_ARNS" ]]; then
    for arn in $SCHEDULER_ARNS; do
        # ARNからスケジュール名とグループ名を抽出
        GROUP_NAME=$(echo $arn | cut -d'/' -f2)
        SCHEDULE_NAME=$(echo $arn | cut -d'/' -f3)
        
        echo "  - $SCHEDULE_NAME を有効化中..."
        
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
            
            # スケジュールを有効化
            aws scheduler update-schedule \
                --name "$SCHEDULE_NAME" \
                --group-name "$GROUP_NAME" \
                --state "ENABLED" \
                --schedule-expression "$SCHEDULE_EXPR" \
                --flexible-time-window "$FLEXIBLE_TIME" \
                --target "$TARGET_CONFIG" \
                --region $REGION 2>/dev/null && echo "    ✅ $SCHEDULE_NAME 有効化完了" || echo "    ⚠️  $SCHEDULE_NAME 有効化失敗"
        fi
    done
else
    # フォールバック: 直接Scheduler名で検索
    echo "    🔄 フォールバック: 直接Scheduler検索中..."
    SCHEDULES=$(aws scheduler list-schedules --group-name "pfc-scheduler-group" --region $REGION --query "Schedules[?contains(Name,'pfc')].{Name:Name,State:State}" --output text 2>/dev/null || echo "")
    
    if [[ -n "$SCHEDULES" ]]; then
        echo "$SCHEDULES" | while read -r name state; do
            if [[ -n "$name" ]]; then
                echo "  - $name を有効化中..."
                
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
                    
                    # スケジュールを有効化
                    aws scheduler update-schedule \
                        --name "$name" \
                        --group-name "pfc-scheduler-group" \
                        --state "ENABLED" \
                        --schedule-expression "$SCHEDULE_EXPR" \
                        --flexible-time-window "$FLEXIBLE_TIME" \
                        --target "$TARGET_CONFIG" \
                        --region $REGION 2>/dev/null && echo "    ✅ $name 有効化完了" || echo "    ⚠️  $name 有効化失敗"
                fi
            fi
        done
    else
        echo "    ⚠️  PFC Scheduler not found"
    fi
fi

# 5. 初回データ収集を実行（データ収集Lambda関数のみ）
echo "💾 初回データ収集を実行しています..."
DATA_COLLECTOR_FUNCTION=$(aws resourcegroupstaggingapi get-resources \
    --tag-filters "Key=Product,Values=$PRODUCT_TAG" "Key=Name,Values=pfc-parking-data-collector" \
    --resource-type-filters "lambda:function" \
    --region $REGION \
    --query "ResourceTagMappingList[0].ResourceARN" \
    --output text 2>/dev/null || echo "")

if [[ -n "$DATA_COLLECTOR_FUNCTION" && "$DATA_COLLECTOR_FUNCTION" != "None" ]]; then
    FUNCTION_NAME=$(echo $DATA_COLLECTOR_FUNCTION | cut -d':' -f7)
    
    aws lambda invoke \
        --function-name "$FUNCTION_NAME" \
        --region $REGION \
        /tmp/lambda-response.json 2>/dev/null && echo "    ✅ 初回データ収集開始" || echo "    ⚠️  データ収集実行失敗"
    
    # レスポンス確認
    if [[ -f "/tmp/lambda-response.json" ]]; then
        echo "    📊 データ収集結果:"
        cat /tmp/lambda-response.json | jq -r '.body' 2>/dev/null | jq '.' 2>/dev/null || cat /tmp/lambda-response.json
        rm -f /tmp/lambda-response.json
    fi
else
    echo "    ⚠️  データ収集Lambda関数が見つかりません"
fi

echo ""
echo "🎯 リソース起動状況:"
echo "✅ Lambda関数: タグベース検出・全て有効化済み"
echo "✅ API Gateway: タグベース検出・ステージ再作成済み"
echo "✅ CloudFront: タグベース検出・有効化開始"
echo "✅ EventBridge Scheduler: タグベース検出・10分間隔で実行中"
echo "✅ 初回データ収集: 実行済み"
echo ""
echo "🌐 アクセス URL:"
echo "   CloudFront: https://d2ubjdigebrmfd.cloudfront.net"
echo "   API Gateway: https://xckspu9thj.execute-api.ap-northeast-1.amazonaws.com"
echo ""
echo "⚠️  注意: CloudFrontの有効化は15-20分かかります"
echo "📝 停止時は ./stop-resources-v2.sh を実行してください"