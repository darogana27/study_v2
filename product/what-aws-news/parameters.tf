module "sqs_parameters" {
  source = "../../modules/aws/parameter_store"

  product = local.env.product
  parameters = {
    "Line_Access_Token" = {
    }
  }
}