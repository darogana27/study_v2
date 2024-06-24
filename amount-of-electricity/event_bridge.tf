# イベントブリッジスケジュールグループの作成
resource "aws_scheduler_schedule_group" "electricity" {
  name = local.name

  tags = {
    name = local.name
  }
}