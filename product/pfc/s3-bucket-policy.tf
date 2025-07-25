# S3バケットポリシー（CloudFront OACアクセス許可）
resource "aws_s3_bucket_policy" "cloudfront_oac_policy" {
  bucket = module.pfc_s3_bucket.s3_ids["pfc-temp-bucket"]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${module.pfc_s3_bucket.s3_arns["pfc-temp-bucket"]}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = module.pfc_cloudfront.cloudfront_distribution_arns["main"]
          }
        }
      }
    ]
  })
}

# S3バケットのパブリックアクセスブロック設定
resource "aws_s3_bucket_public_access_block" "pfc_bucket_pab" {
  bucket = module.pfc_s3_bucket.s3_ids["pfc-temp-bucket"]

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}