#!/bin/bash

# PFC Master Deployment Script
# 東京全域対応システムの完全デプロイメント

set -e

echo "🚲 PFC Tokyo-Wide Deployment - Complete System Setup"

# プロジェクトディレクトリを確認
cd "$(dirname "$0")"
PROJECT_ROOT="$(pwd)"

echo "📁 Project root: $PROJECT_ROOT"

# コマンドライン引数を処理
DEPLOY_INFRA=true
DEPLOY_LAMBDA=true
DEPLOY_FRONTEND=true
SKIP_CONFIRMATION=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-infra)
            DEPLOY_INFRA=false
            shift
            ;;
        --skip-lambda)
            DEPLOY_LAMBDA=false
            shift
            ;;
        --skip-frontend)
            DEPLOY_FRONTEND=false
            shift
            ;;
        --yes|-y)
            SKIP_CONFIRMATION=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  --skip-infra     Skip infrastructure deployment"
            echo "  --skip-lambda    Skip Lambda functions deployment"
            echo "  --skip-frontend  Skip frontend deployment"
            echo "  --yes, -y        Skip confirmation prompts"
            echo "  --help, -h       Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# 前提条件チェック
echo "🔍 Checking prerequisites..."

# AWS CLI
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI not found. Please install AWS CLI first."
    exit 1
fi

# Terraform
if ! command -v terraform &> /dev/null; then
    echo "❌ Terraform not found. Please install Terraform first."
    exit 1
fi

# Node.js (フロントエンドをデプロイする場合)
if [ "$DEPLOY_FRONTEND" = true ] && ! command -v npm &> /dev/null; then
    echo "❌ npm not found. Please install Node.js first."
    exit 1
fi

# Python (Lambdaをデプロイする場合)
if [ "$DEPLOY_LAMBDA" = true ] && ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 not found. Please install Python 3 first."
    exit 1
fi

echo "✅ Prerequisites check passed"

# AWS認証情報チェック
echo "🔐 Checking AWS credentials..."
if ! aws sts get-caller-identity &> /dev/null; then
    echo "❌ AWS credentials not configured. Please run 'aws configure' first."
    exit 1
fi

AWS_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=$(aws configure get region || echo "us-east-1")
echo "✅ AWS Account: $AWS_ACCOUNT"
echo "✅ AWS Region: $AWS_REGION"

# 確認プロンプト
if [ "$SKIP_CONFIRMATION" != true ]; then
    echo ""
    echo "📋 Deployment Plan:"
    [ "$DEPLOY_INFRA" = true ] && echo "  ✅ Infrastructure (Terraform)"
    [ "$DEPLOY_LAMBDA" = true ] && echo "  ✅ Lambda Functions"
    [ "$DEPLOY_FRONTEND" = true ] && echo "  ✅ Frontend Application"
    echo ""
    read -p "🤔 Proceed with deployment? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "⏭️  Deployment cancelled"
        exit 0
    fi
fi

# 1. インフラストラクチャデプロイ
if [ "$DEPLOY_INFRA" = true ]; then
    echo "🏗️  Deploying infrastructure..."
    cd "$PROJECT_ROOT/infrastructure"
    
    # Terraform初期化
    terraform init
    
    # プランを確認
    terraform plan
    
    if [ "$SKIP_CONFIRMATION" != true ]; then
        read -p "🤔 Apply infrastructure changes? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "⏭️  Infrastructure deployment skipped"
            DEPLOY_INFRA=false
        fi
    fi
    
    if [ "$DEPLOY_INFRA" = true ]; then
        terraform apply -auto-approve
        echo "✅ Infrastructure deployed successfully"
    fi
    
    cd "$PROJECT_ROOT"
fi

# 2. Lambda関数デプロイ
if [ "$DEPLOY_LAMBDA" = true ]; then
    echo "🔧 Deploying Lambda functions..."
    cd "$PROJECT_ROOT/src/lambda"
    
    # ビルドとデプロイスクリプトを実行
    if [ -x "./build_and_deploy.sh" ]; then
        ./build_and_deploy.sh
    else
        echo "❌ Lambda build script not found or not executable"
        exit 1
    fi
    
    echo "✅ Lambda functions deployed successfully"
    cd "$PROJECT_ROOT"
fi

# 3. フロントエンドデプロイ
if [ "$DEPLOY_FRONTEND" = true ]; then
    echo "🌐 Deploying frontend application..."
    cd "$PROJECT_ROOT/src/web"
    
    # ビルドとデプロイスクリプトを実行
    if [ -x "./build-and-deploy.sh" ]; then
        ./build-and-deploy.sh
    else
        echo "❌ Frontend build script not found or not executable"
        exit 1
    fi
    
    echo "✅ Frontend deployed successfully"
    cd "$PROJECT_ROOT"
fi

# デプロイメント完了
echo ""
echo "🎉 PFC Tokyo-Wide Deployment Completed!"
echo ""

# 重要な出力情報を表示
if [ "$DEPLOY_INFRA" = true ]; then
    echo "📋 Deployment Information:"
    cd "$PROJECT_ROOT/infrastructure"
    
    if [ -f "terraform.tfstate" ]; then
        API_ENDPOINT=$(terraform output -raw api_endpoint 2>/dev/null || echo "N/A")
        CLOUDFRONT_URL=$(terraform output -raw cloudfront_url 2>/dev/null || echo "N/A")
        S3_BUCKET=$(terraform output -raw s3_bucket_name 2>/dev/null || echo "N/A")
        DYNAMODB_TABLE=$(terraform output -raw dynamodb_table_name 2>/dev/null || echo "N/A")
        
        echo "  🌐 Application URL: $CLOUDFRONT_URL"
        echo "  🔗 API Endpoint: $API_ENDPOINT"
        echo "  🪣 S3 Bucket: $S3_BUCKET"
        echo "  🗃️  DynamoDB Table: $DYNAMODB_TABLE"
    fi
    
    cd "$PROJECT_ROOT"
fi

echo ""
echo "🚀 Next Steps:"
echo "1. Wait a few minutes for CloudFront distribution to fully deploy"
echo "2. Test the application by visiting the CloudFront URL"
echo "3. Try Tokyo-wide search functionality"
echo "4. Monitor CloudWatch logs for any issues"
echo ""
echo "🔧 Troubleshooting:"
echo "- Check CloudWatch logs if API calls fail"
echo "- Verify DynamoDB table has data after first data collection"
echo "- Ensure API Gateway endpoints are properly configured"