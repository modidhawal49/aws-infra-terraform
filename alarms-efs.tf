# Assume you have aws_efs_file_system.main or similar. If module, swap the ID.
data "aws_efs_file_system" "selected" {
  file_system_id = aws_efs_file_system.this.id
}

resource "aws_cloudwatch_metric_alarm" "efs_burst_credits_low" {
  alarm_name          = "${var.name_prefix}-efs-burst-credits-low"
  namespace           = "AWS/EFS"
  metric_name         = "BurstCreditBalance"
  statistic           = "Minimum"
  period              = var.alarm_period_seconds
  evaluation_periods  = var.alarm_eval_periods
  comparison_operator = "LessThanThreshold"
  threshold           = var.efs_burst_credit_min
  dimensions          = { FileSystemId = data.aws_efs_file_system.selected.id }
  alarm_actions       = local.cw_actions
  tags                = local.tags
}

resource "aws_cloudwatch_metric_alarm" "efs_percent_io_limit" {
  alarm_name          = "${var.name_prefix}-efs-percent-io-limit"
  namespace           = "AWS/EFS"
  metric_name         = "PercentIOLimit"
  statistic           = "Maximum"
  period              = var.alarm_period_seconds
  evaluation_periods  = var.alarm_eval_periods
  comparison_operator = "GreaterThanThreshold"
  threshold           = var.efs_percent_io_limit
  dimensions          = { FileSystemId = data.aws_efs_file_system.selected.id }
  alarm_actions       = local.cw_actions
  tags                = local.tags
}

resource "aws_cloudwatch_metric_alarm" "efs_client_conn_high" {
  alarm_name          = "${var.name_prefix}-efs-client-connections-high"
  namespace           = "AWS/EFS"
  metric_name         = "ClientConnections"
  statistic           = "Average"
  period              = var.alarm_period_seconds
  evaluation_periods  = var.alarm_eval_periods
  comparison_operator = "GreaterThanThreshold"
  threshold           = var.efs_client_conn_high
  dimensions          = { FileSystemId = data.aws_efs_file_system.selected.id }
  alarm_actions       = local.cw_actions
  tags                = local.tags
}

