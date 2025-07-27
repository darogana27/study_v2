# 使用方法

## make-productコマンド

新しいプロジェクトを作成するためのコマンドです。

### 基本使用法

```bash
make-product -name <プロジェクト名> [-region <リージョン>]
```

### オプション

- `-name`: プロジェクト名（必須）
- `-region`: AWSリージョン（オプション、デフォルト: ap-northeast-1）
- `-h, --help`: ヘルプを表示

### 例

```bash
# 基本的な使用
make-product -name my-app

# リージョンを指定
make-product -name user-service -region us-east-1
```

## プロジェクト構造

作成されるプロジェクトの構造：

```
product/my-app/
├── README.md
├── terraform.tf          # Provider設定
├── backend.tf            # リモートバックエンド設定
├── main.tf              # メインリソース
├── terraform.tfvars     # 変数値
├── apigateway.tf        # API Gateway
├── dynamodb.tf          # DynamoDB
├── lambda.tf            # Lambda
├── s3.tf                # S3
└── sqs.tf               # SQS
```

## 利用可能なモジュール

### AWS サービスモジュール

- `modules/aws/apigateway/` - API Gateway
- `modules/aws/cloudfront/` - CloudFront
- `modules/aws/dynamodb/` - DynamoDB
- `modules/aws/ecr/` - ECR
- `modules/aws/eventbridge/scheduler/` - EventBridge Scheduler
- `modules/aws/lambda/` - Lambda
- `modules/aws/parameter_store/` - Parameter Store
- `modules/aws/s3/` - S3
- `modules/aws/sns/` - SNS
- `modules/aws/sqs/` - SQS
- `modules/aws/step_function/` - Step Functions

### モジュールの使用例

```hcl
module "lambda" {
  source = "../../modules/aws/lambda"
  
  function_name = var.function_name
  runtime       = "python3.9"
  handler       = "lambda_function.lambda_handler"
  
  tags = var.common_tags
}
```

## Terraformエイリアス

便利なTerraformコマンドエイリアス：

```bash
tffirst  # terraform fmt && terraform init && terraform plan
tfinit   # terraform fmt && terraform init
tfplan   # terraform fmt && terraform plan
tfapply  # terraform fmt && terraform apply
```