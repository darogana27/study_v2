#!/bin/bash

# PFC Lambda Functions Build and Deploy Script
# 東京全域対応のLambda関数をビルド・デプロイ

set -e

echo "🚀 PFC Lambda Build & Deploy - Tokyo Wide Edition"

# プロジェクトディレクトリに移動
cd "$(dirname "$0")"
PROJECT_ROOT="$(cd ../.. && pwd)"

echo "📁 Project root: $PROJECT_ROOT"
echo "📂 Lambda source: $(pwd)"

# 必要なディレクトリを作成
mkdir -p builds

# Python依存関係をインストール（必要な場合）
if [ -f "requirements.txt" ]; then
    echo "📦 Installing Python dependencies..."
    pip install -r requirements.txt -t ./temp_packages
fi

# Lambda関数のリスト（東京全域対応）
FUNCTIONS=(
    "park-finder-chat:park-finder-chat.py:PFC Park Finder Chat Function - Tokyo Wide"
    "parking-spots-api:parking-spots-api.py:PFC Parking Spots API Function - Tokyo Wide"
    "parking-data-collector:tokyo-parking-data-collector.py:PFC Tokyo Parking Data Collector Function"
)

echo "🔨 Building Lambda functions..."

for function_info in "${FUNCTIONS[@]}"; do
    IFS=':' read -r func_name source_file description <<< "$function_info"
    
    echo "📦 Building $func_name..."
    
    # 一時ディレクトリを作成
    temp_dir="temp_${func_name}"
    rm -rf "$temp_dir"
    mkdir "$temp_dir"
    
    # メインのPythonファイルをコピー
    if [ -f "$source_file" ]; then
        cp "$source_file" "$temp_dir/"
    else
        echo "⚠️  Source file $source_file not found for $func_name"
        continue
    fi
    
    # 共通依存関係をコピー（存在する場合）
    if [ -d "temp_packages" ]; then
        cp -r temp_packages/* "$temp_dir/"
    fi
    
    # 特定の関数に必要な追加ファイルをコピー
    case $func_name in
        "park-finder-chat")
            echo "  ✅ Chat function - ready for Tokyo-wide support"
            ;;
        "parking-spots-api")
            echo "  ✅ API function - geographic search enabled"
            ;;
        "parking-data-collector")
            echo "  ✅ Data collector - Tokyo-wide collection enabled"
            ;;
    esac
    
    # ZIPファイルを作成
    cd "$temp_dir"
    zip -r "../builds/${func_name}.zip" . -q
    cd ..
    
    # 一時ディレクトリを削除
    rm -rf "$temp_dir"
    
    echo "  ✅ $func_name.zip created"
done

# 一時的な依存関係ディレクトリを削除
rm -rf temp_packages

echo "✅ All Lambda functions built successfully!"

# Lambda関数をAWSにデプロイ
echo "🚀 Deploying Lambda functions to AWS..."

cd "$PROJECT_ROOT/infrastructure"

if [ -f "terraform.tfstate" ]; then
    echo "📋 Updating Lambda functions via Terraform..."
    terraform plan -target=module.lambda_functions
    
    read -p "🤔 Do you want to apply these changes? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        terraform apply -target=module.lambda_functions -auto-approve
        echo "✅ Lambda functions updated successfully!"
    else
        echo "⏭️  Deployment skipped"
    fi
else
    echo "⚠️  Terraform state not found"
    echo "💡 Please ensure infrastructure is deployed first"
fi

cd "$PROJECT_ROOT/src/lambda"

echo "🎉 Lambda build and deploy process completed!"
echo ""
echo "📋 Functions built and ready:"
for function_info in "${FUNCTIONS[@]}"; do
    IFS=':' read -r func_name source_file description <<< "$function_info"
    if [ -f "builds/${func_name}.zip" ]; then
        size=$(du -h "builds/${func_name}.zip" | cut -f1)
        echo "  ✅ $func_name.zip ($size)"
    fi
done

echo ""
echo "🔧 Next steps:"
echo "1. Test the chat function with Tokyo-wide selections"
echo "2. Verify API function returns Tokyo-wide data"
echo "3. Check data collector populates all Tokyo areas"
echo "4. Monitor CloudWatch logs for any issues"