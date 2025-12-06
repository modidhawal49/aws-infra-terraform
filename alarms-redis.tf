############################################
# ElastiCache/Redis CloudWatch Alarms (wired to SNS)
############################################
locals {
  # For a replication group (recommended):
  redis_dim = { ReplicationGroupId = aws_elasticache_replication_group.redis.id }

  # If you’re alarming per-cache node instead, use:
  # redis_dim = { CacheClusterId = aws_elasticache_cluster.redis.id }
}

############################################
# CPU high
############################################
resource "aws_cloudwatch_metric_alarm" "redis_cpu_high" {
  alarm_name          = "${var.name_prefix}-redis-cpu-high"
  namespace           = "AWS/ElastiCache"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = var.alarm_period_seconds
  evaluation_periods  = var.alarm_eval_periods
  comparison_operator = "GreaterThanThreshold"
  threshold           = var.redis_cpu_pct

  dimensions = local.redis_dim

  alarm_actions             = local.cw_actions
  ok_actions                = local.cw_actions
  insufficient_data_actions = local.cw_actions
  treat_missing_data        = "notBreaching"

  tags = local.tags
}

############################################
# Connections high
############################################
resource "aws_cloudwatch_metric_alarm" "redis_connections_high" {
  alarm_name          = "${var.name_prefix}-redis-connections-high"
  namespace           = "AWS/ElastiCache"
  metric_name         = "CurrConnections"
  statistic           = "Average"
  period              = var.alarm_period_seconds
  evaluation_periods  = var.alarm_eval_periods
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = var.redis_curr_conn

  dimensions = local.redis_dim

  alarm_actions             = local.cw_actions
  ok_actions                = local.cw_actions
  insufficient_data_actions = local.cw_actions
  treat_missing_data        = "notBreaching"

  tags = local.tags
}

############################################
# Freeable Memory low (MiB -> bytes)
############################################
resource "aws_cloudwatch_metric_alarm" "redis_freeable_memory_low" {
  alarm_name          = "${var.name_prefix}-redis-freeable-memory-low"
  namespace           = "AWS/ElastiCache"
  metric_name         = "FreeableMemory"
  statistic           = "Average"
  period              = var.alarm_period_seconds
  evaluation_periods  = var.alarm_eval_periods
  comparison_operator = "LessThanThreshold"
  threshold           = var.redis_freeable_mb * 1024 * 1024

  dimensions = local.redis_dim

  alarm_actions             = local.cw_actions
  ok_actions                = local.cw_actions
  insufficient_data_actions = local.cw_actions
  treat_missing_data        = "notBreaching"

  tags = local.tags
}

############################################
# Evictions > threshold
############################################
resource "aws_cloudwatch_metric_alarm" "redis_evictions" {
  alarm_name          = "${var.name_prefix}-redis-evictions"
  namespace           = "AWS/ElastiCache"
  metric_name         = "Evictions"
  statistic           = "Sum"
  period              = var.alarm_period_seconds
  evaluation_periods  = var.alarm_eval_periods
  comparison_operator = "GreaterThanThreshold"
  threshold           = var.redis_evictions

  dimensions = local.redis_dim

  alarm_actions             = local.cw_actions
  ok_actions                = local.cw_actions
  insufficient_data_actions = local.cw_actions
  treat_missing_data        = "notBreaching"

  tags = local.tags
}

############################################
# Replication lag high
############################################
resource "aws_cloudwatch_metric_alarm" "redis_replication_lag" {
  alarm_name          = "${var.name_prefix}-redis-replication-lag"
  namespace           = "AWS/ElastiCache"
  metric_name         = "ReplicationLag"
  statistic           = "Maximum"
  period              = var.alarm_period_seconds
  evaluation_periods  = var.alarm_eval_periods
  comparison_operator = "GreaterThanThreshold"
  threshold           = var.redis_replication_lag

  dimensions = local.redis_dim

  alarm_actions             = local.cw_actions
  ok_actions                = local.cw_actions
  insufficient_data_actions = local.cw_actions
  treat_missing_data        = "notBreaching"

  tags = local.tags
}

############################################
# Swap usage high (MiB -> bytes)
############################################
resource "aws_cloudwatch_metric_alarm" "redis_swap_usage_high" {
  alarm_name          = "${var.name_prefix}-redis-swap-usage-high"
  namespace           = "AWS/ElastiCache"
  metric_name         = "SwapUsage"
  statistic           = "Maximum"
  period              = var.alarm_period_seconds
  evaluation_periods  = var.alarm_eval_periods
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = var.redis_swap_usage_mb * 1024 * 1024

  dimensions = local.redis_dim

  alarm_actions             = local.cw_actions
  ok_actions                = local.cw_actions
  insufficient_data_actions = local.cw_actions
  treat_missing_data        = "notBreaching"

  tags = local.tags
}

