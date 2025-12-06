# High CPU
resource "aws_cloudwatch_metric_alarm" "rds_cpu_high" {
  count = 0
  alarm_name          = "${var.name_prefix}-rds-cpu-high"
  namespace           = "AWS/RDS"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = var.alarm_period_seconds
  evaluation_periods  = var.alarm_eval_periods
  comparison_operator = "GreaterThanThreshold"
  threshold           = var.rds_cpu_pct
  dimensions          = { DBInstanceIdentifier = module.db.db_instance_identifier }
  alarm_actions       = local.cw_actions
  tags                = local.tags
}

# Low free storage
resource "aws_cloudwatch_metric_alarm" "rds_free_storage_low" {
  alarm_name          = "${var.name_prefix}-rds-free-storage-low"
  namespace           = "AWS/RDS"
  metric_name         = "FreeStorageSpace"
  statistic           = "Average"
  period              = var.alarm_period_seconds
  evaluation_periods  = var.alarm_eval_periods
  comparison_operator = "LessThanThreshold"
  threshold           = var.rds_free_storage_mb * 1024 * 1024
  dimensions          = { DBInstanceIdentifier = module.db.db_instance_identifier }
  alarm_actions       = local.cw_actions
  tags                = local.tags
}

# High connections
resource "aws_cloudwatch_metric_alarm" "rds_connections_high" {
  alarm_name          = "${var.name_prefix}-rds-connections-high"
  namespace           = "AWS/RDS"
  metric_name         = "DatabaseConnections"
  statistic           = "Average"
  period              = var.alarm_period_seconds
  evaluation_periods  = var.alarm_eval_periods
  comparison_operator = "GreaterThanThreshold"
  threshold           = var.rds_conn_high
  dimensions          = { DBInstanceIdentifier = module.db.db_instance_identifier }
  alarm_actions       = local.cw_actions
  tags                = local.tags
}

