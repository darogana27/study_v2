# module "state_machines" {
#   source  = "../../modules/aws/step_function"
#   product = local.env.product
#   state_machine = {
#     translate = {
#       # definition = {}
#       additional_policies = [
#         {
#           effect = "Allow"
#           actions = [
#             "lambda:InvokeFunction",
#           ]
#           resources = [
#             "arn:aws:lambda:${local.env.region}:${local.env.account_id}:function:*"
#           ]
#         }
#       ]
#     },
#     get_all_tag_services = {
#       # definition = {}
#       additional_policies = [
#         {
#           effect = "Allow"
#           actions = [
#             "lambda:InvokeFunction",
#           ]
#           resources = [
#             "arn:aws:lambda:${local.env.region}:${local.env.account_id}:function:*"
#           ]
#         }
#       ]
#     },
#   }

#   account_id = data.aws_caller_identity.self.account_id
#   region     = data.aws_region.self.name
# }