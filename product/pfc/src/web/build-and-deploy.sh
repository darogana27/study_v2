#!/bin/bash

# PFC Frontend Build and Deploy Script
# 東京全域対応のフロントエンドをビルド・デプロイ

set -e

echo "🚀 PFC Frontend Build & Deploy - Tokyo Wide Edition"

# プロジェクトディレクトリに移動
cd "$(dirname "$0")"
PROJECT_ROOT="$(cd ../../.. && pwd)"

echo "📁 Project root: $PROJECT_ROOT"

# Terraformから API Gateway エンドポイントを取得
echo "🔗 Getting API endpoint from Terraform..."
cd "$PROJECT_ROOT/infrastructure"

if [ -f "terraform.tfstate" ]; then
    API_ENDPOINT=$(terraform output -raw api_endpoint 2>/dev/null || echo "")
    if [ -n "$API_ENDPOINT" ]; then
        echo "✅ API Endpoint found: $API_ENDPOINT"
        # API エンドポイントに /chat を追加
        CHAT_ENDPOINT="${API_ENDPOINT}/chat"
        echo "🎯 Chat Endpoint: $CHAT_ENDPOINT"
    else
        echo "⚠️  API endpoint not found in Terraform state"
        CHAT_ENDPOINT="https://your-api-gateway-url.amazonaws.com/prod/chat"
    fi
else
    echo "⚠️  Terraform state not found, using default endpoint"
    CHAT_ENDPOINT="https://your-api-gateway-url.amazonaws.com/prod/chat"
fi

# webディレクトリに戻る
cd "$PROJECT_ROOT/src/web"

# 環境変数ファイルを作成
echo "📝 Creating environment configuration..."
cat > .env << EOF
REACT_APP_API_ENDPOINT=$CHAT_ENDPOINT
REACT_APP_ENABLE_TOKYO_WIDE=true
REACT_APP_BUILD_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
EOF

echo "✅ Environment configuration created"

# npm依存関係をインストール（必要な場合）
if [ ! -d "node_modules" ]; then
    echo "📦 Installing npm dependencies..."
    npm install
fi

# ビルド実行
echo "🔨 Building React application..."
npm run build

echo "✅ Build completed successfully!"

# S3バケット名を取得
echo "🪣 Getting S3 bucket name from Terraform..."
cd "$PROJECT_ROOT/infrastructure"

if [ -f "terraform.tfstate" ]; then
    S3_BUCKET=$(terraform output -raw s3_bucket_name 2>/dev/null || echo "")
    if [ -n "$S3_BUCKET" ]; then
        echo "✅ S3 Bucket found: $S3_BUCKET"
        
        # S3にデプロイ
        echo "🚀 Deploying to S3..."
        cd "$PROJECT_ROOT/src/web"
        aws s3 sync dist/ "s3://$S3_BUCKET/" --delete
        
        echo "✅ Deployment completed!"
        
        # CloudFront URLを取得して表示
        cd "$PROJECT_ROOT/infrastructure"
        CLOUDFRONT_URL=$(terraform output -raw cloudfront_url 2>/dev/null || echo "")
        if [ -n "$CLOUDFRONT_URL" ]; then
            echo "🌐 Application URL: $CLOUDFRONT_URL"
        fi
    else
        echo "⚠️  S3 bucket name not found in Terraform state"
        echo "💡 Manual deployment required"
    fi
else
    echo "⚠️  Terraform state not found"
    echo "💡 Please deploy infrastructure first with: cd infrastructure && terraform apply"
fi

echo "🎉 Build and deploy process completed!"
echo ""
echo "📋 Next steps:"
echo "1. Verify the application loads at the CloudFront URL"
echo "2. Test Tokyo-wide search functionality"
echo "3. Check API Gateway logs if there are issues"