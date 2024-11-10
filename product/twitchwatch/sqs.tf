# module "sqs_queues" {
#   source = "../../modules/aws/sqs"

#   sqs = {
#     "queue1" = {
#       delay_seconds             = 60
#       max_message_size          = 1024
#       message_retention_seconds = 43200
#       receive_wait_time_seconds = 20
#     },
#     "queue2" = {
#       # ここに他の設定が必要であれば追加
#     }
#   }
# }