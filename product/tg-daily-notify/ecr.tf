resource "aws_ecr_repository" "daily-electricity" {
  name = "daily-electricity"
}

module "ecr" {
  source = "../../modules/aws/ecr"

  product = local.env.product

  repositories = {
    "daily-electricity" = {
      # image_tag_mutability = "IMMUTABLE"
      # scan_on_push = true
      # force_delete = true
    }
  }
}