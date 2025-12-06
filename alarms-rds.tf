############################################
# RDS CloudWatch Alarms (wired to SNS)
############################################
# Assumes:
# - module.db.db_instance_identifier -> your DB instance identifier
# - local.cw_actions -> [aws_sns_topic.alerts.arn]
# - local.tags        -> common tags
#
# Threshold variables expected:
# - var.rds_cpu_pct
# - var.rds_free_storage_mb
# - var.rds_freeable_mb
# - var.rds_db_connections
# - var.rds_read_lat_ms
# - var.rds_write_lat_ms
# - (optional) var.rds_replica_lag

############################################
# High CPU
############################################
resource "aws_cloudwatch_metric_alarm" "rds_cpu_high" {
  alarm_name          = "${var.name_prefix}-rds-cpu-high"
  namespace           = "AWS/RDS"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = var.alarm_period_seconds
  evaluation_periods  = var.alarm_eval_periods
  comparison_operator = "GreaterThanThreshold"
  threshold           = var.rds_cpu_pct

  dimensions = {
    DBInstanceIdentifier = module.db.db_instance_identifier
  }

  alarm_actions             = local.cw_actions
  ok_actions                = local.cw_actions
  insufficient_data_actions = local.cw_actions
  treat_missing_data        = "notBreaching"

  tags = local.tags
}

############################################
# Free storage low (MiB -> bytes)
############################################
resource "aws_cloudwatch_metric_alarm" "rds_free_storage_low" {
  alarm_name          = "${var.name_prefix}-rds-free-storage-low"
  namespace           = "AWS/RDS"
  metric_name         = "FreeStorageSpace"
  statistic           = "Average"
  period              = var.alarm_period_seconds
  evaluation_periods  = var.alarm_eval_periods
  comparison_operator = "LessThanThreshold"
  threshold           = var.rds_free_storage_mb * 1024 * 1024

  dimensions = {
    DBInstanceIdentifier = module.db.db_instance_identifier
  }

  alarm_actions             = local.cw_actions
  ok_actions                = local.cw_actions
  insufficient_data_actions = local.cw_actions
  treat_missing_data        = "notBreaching"

  tags = local.tags
}

############################################
# Freeable Memory low (MiB -> bytes)
############################################
resource "aws_cloudwatch_metric_alarm" "rds_freeable_memory_low" {
  alarm_name          = "${var.name_prefix}-rds-freeable-memory-low"
  namespace           = "AWS/RDS"
  metric_name         = "FreeableMemory"
  statistic           = "Average"
  period              = var.alarm_period_seconds
  evaluation_periods  = var.alarm_eval_periods
  comparison_operator = "LessThanThreshold"
  threshold           = var.rds_freeable_mb * 1024 * 1024

  dimensions = {
    DBInstanceIdentifier = module.db.db_instance_identifier
  }

  alarm_actions             = local.cw_actions
  ok_actions                = local.cw_actions
  insufficient_data_actions = local.cw_actions
  treat_missing_data        = "notBreaching"

  tags = local.tags
}

############################################
# Database connections high
############################################
resource "aws_cloudwatch_metric_alarm" "rds_db_connections_high" {
  alarm_name          = "${var.name_prefix}-rds-db-connections-high"
  namespace           = "AWS/RDS"
  metric_name         = "DatabaseConnections"
  statistic           = "Average"
  period              = var.alarm_period_seconds
  evaluation_periods  = var.alarm_eval_periods
  comparison_operator = "GreaterThanThreshold"
  threshold           = var.rds_db_connections

  dimensions = {
    DBInstanceIdentifier = module.db.db_instance_identifier
  }

  alarm_actions             = local.cw_actions
  ok_actions                = local.cw_actions
  insufficient_data_actions = local.cw_actions
  treat_missing_data        = "notBreaching"

  tags = local.tags
}

############################################
# Read latency p95 (seconds)
############################################
resource "aws_cloudwatch_metric_alarm" "rds_read_latency_p95" {
  alarm_name          = "${var.name_prefix}-rds-read-latency-p95"
  namespace           = "AWS/RDS"
  metric_name         = "ReadLatency"
  extended_statistic  = "p95"
  period              = var.alarm_period_seconds
  evaluation_periods  = var.alarm_eval_periods
  comparison_operator = "GreaterThanThreshold"
  threshold           = var.rds_read_lat_ms / 1000.0

  dimensions = {
    DBInstanceIdentifier = module.db.db_instance_identifier
  }

  alarm_actions             = local.cw_actions
  ok_actions                = local.cw_actions
  insufficient_data_actions = local.cw_actions
  treat_missing_data        = "notBreaching"

  tags = local.tags
}

############################################
# Write latency p95 (seconds)
############################################
resource "aws_cloudwatch_metric_alarm" "rds_write_latency_p95" {
  alarm_name          = "${var.name_prefix}-rds-write-latency-p95"
  namespace           = "AWS/RDS"
  metric_name         = "WriteLatency"
  extended_statistic  = "p95"
  period              = var.alarm_period_seconds
  evaluation_periods  = var.alarm_eval_periods
  comparison_operator = "GreaterThanThreshold"
  threshold           = var.rds_write_lat_ms / 1000.0

  dimensions = {
    DBInstanceIdentifier = module.db.db_instance_identifier
  }

  alarm_actions             = local.cw_actions
  ok_actions                = local.cw_actions
  insufficient_data_actions = local.cw_actions
  treat_missing_data        = "notBreaching"

  tags = local.tags
}

############################################
# Replica lag (optional, only if replicas exist)
############################################
resource "aws_cloudwatch_metric_alarm" "rds_replica_lag" {
  count               = try(var.rds_replica_lag, null) == null ? 0 : 1
  alarm_name          = "${var.name_prefix}-rds-replica-lag"
  namespace           = "AWS/RDS"
  metric_name         = "ReplicaLag"
  statistic           = "Maximum"
  period              = var.alarm_period_seconds
  evaluation_periods  = var.alarm_eval_periods
  comparison_operator = "GreaterThanThreshold"
  threshold           = var.rds_replica_lag

  dimensions = {
    DBInstanceIdentifier = module.db.db_instance_identifier
  }

  alarm_actions             = local.cw_actions
  ok_actions                = local.cw_actions
  insufficient_data_actions = local.cw_actions
  treat_missing_data        = "notBreaching"

  tags = local.tags
}

