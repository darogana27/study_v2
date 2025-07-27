
# S3 バケットモジュール

このTerraformモジュールは、ライフサイクルポリシー、バージョニング、暗号化、アクセス制御、通知など、さまざまな設定を持つS3バケットを作成および管理します。

## 使用方法

このモジュールを使用するには、Terraform構成に含め、必要な変数を提供します。

### 例

```hcl
module "s3_buckets" {
  source = "./path/to/this/module"

  project_name = "my_project"
  
  s3_bucket = {
    bucket1 = {
      s3_bucket_name           = "my-first-bucket"
      force_destroy            = true
      accelerate_configuration = "Enabled"
      bucket_acl               = "private"
      object_ownership         = "BucketOwnerPreferred"
      versioning_status        = "Enabled"
      encryption_algorithm     = "AES256"
      block_public_acls        = true
      block_public_policy      = true
      ignore_public_acls       = true
      restrict_public_buckets  = true
      lifecycle_rules = [
        {
          id      = "rule1"
          prefix  = ""
          enabled = true
          transitions = [
            {
              days          = 30
              storage_class = "GLACIER"
            }
          ]
          expiration = {
            days = 365
          }
        }
      ]
      notifications = [
        {
          event_type         = "s3:ObjectCreated:*"
          lambda_function_arn = "arn:aws:lambda:us-east-1:123456789012:function:my-function"
        }
      ]
    }
  }
}
```

## 変数

### `project_name`

- タイプ: `string`
- デフォルト: `null`
- 説明: プロジェクトの名前。

### `s3_bucket`

- タイプ: `map(object({...}))`
- 説明: S3バケットの設定を定義します。

各オブジェクトのプロパティは以下の通りです:

- `s3_bucket_name`: (必須) バケットの名前。
- `force_destroy`: (オプション, デフォルト: `true`) バケットを強制的に削除するかどうか。
- `object_lock_enabled`: (オプション, デフォルト: `false`) オブジェクトロックを有効にするかどうか。
- `accelerate_configuration`: (オプション, デフォルト: `"Suspended"`) 転送加速の設定。
- `bucket_acl`: (オプション, デフォルト: `"private"`) バケットのACL設定。
- `object_ownership`: (オプション, デフォルト: `"BucketOwnerPreferred"`) オブジェクト所有権の設定。
- `versioning_status`: (オプション, デフォルト: `"Enabled"`) バージョニングのステータス。
- `encryption_algorithm`: (オプション, デフォルト: `"AES256"`) サーバー側の暗号化アルゴリズム。
- `block_public_acls`: (オプション, デフォルト: `true`) パブリックACLをブロックするかどうか。
- `block_public_policy`: (オプション, デフォルト: `true`) パブリックポリシーをブロックするかどうか。
- `ignore_public_acls`: (オプション, デフォルト: `true`) パブリックACLを無視するかどうか。
- `restrict_public_buckets`: (オプション, デフォルト: `true`) パブリックバケットを制限するかどうか。
- `lifecycle_rules`: (オプション) ライフサイクルルールのリスト。
- `notifications`: (オプション) 通知設定のリスト。

## ライフサイクルルール

各ライフサイクルルールは以下のプロパティを持ちます:

- `id`: (必須) ルールのID。
- `prefix`: (オプション) ルールが適用されるオブジェクトのプレフィックス。
- `enabled`: (オプション, デフォルト: `true`) ルールが有効かどうか。
- `transitions`: (オプション) オブジェクトのストレージクラスを変更する遷移設定のリスト。
- `expiration`: (オプション) オブジェクトの有効期限設定。

## 通知設定

各通知設定は以下のプロパティを持ちます:

- `event_type`: (必須) 通知のイベントタイプ。
- `filter_prefix`: (オプション) フィルタープレフィックス。
- `filter_suffix`: (オプション) フィルターサフィックス。
- `lambda_function_arn`: (オプション) 通知先のLambda関数ARN。
- `topic_arn`: (オプション) 通知先のSNSトピックARN。
- `queue_arn`: (オプション) 通知先のSQSキューARN。
