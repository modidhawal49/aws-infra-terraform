locals {
  redis_dim = (
    aws_elasticache_replication_group.redis.replication_group_id != "" ?
    { ReplicationGroupId = aws_elasticache_replication_group.redis.replication_group_id } :
    { CacheClusterId = aws_elasticache_replication_group.redis.primary_endpoint_address } # fallback
  )
}

resource "aws_cloudwatch_metric_alarm" "redis_cpu_high" {
  alarm_name          = "${var.name_prefix}-redis-cpu-high"
  namespace           = "AWS/ElastiCache"
  metric_name         = "EngineCPUUtilization"
  statistic           = "Average"
  period              = var.alarm_period_seconds
  evaluation_periods  = var.alarm_eval_periods
  comparison_operator = "GreaterThanThreshold"
  threshold           = var.redis_cpu_pct
  dimensions          = local.redis_dim
  alarm_actions       = local.cw_actions
  tags                = local.tags

  lifecycle {
    ignore_changes = all
  }

}

resource "aws_cloudwatch_metric_alarm" "redis_freeable_low" {
  alarm_name          = "${var.name_prefix}-redis-freeable-low"
  namespace           = "AWS/ElastiCache"
  metric_name         = "FreeableMemory"
  statistic           = "Average"
  period              = var.alarm_period_seconds
  evaluation_periods  = var.alarm_eval_periods
  comparison_operator = "LessThanThreshold"
  threshold           = var.redis_freeable_mb * 1024 * 1024
  dimensions          = local.redis_dim
  alarm_actions       = local.cw_actions
  tags                = local.tags

  lifecycle {
    ignore_changes = all
  }

}

resource "aws_cloudwatch_metric_alarm" "redis_evictions" {
  alarm_name          = "${var.name_prefix}-redis-evictions"
  namespace           = "AWS/ElastiCache"
  metric_name         = "Evictions"
  statistic           = "Sum"
  period              = var.alarm_period_seconds
  evaluation_periods  = var.alarm_eval_periods
  comparison_operator = "GreaterThanThreshold"
  threshold           = var.redis_evictions
  dimensions          = local.redis_dim
  alarm_actions       = local.cw_actions
  tags                = local.tags

  lifecycle {
    ignore_changes = all
  }

}

resource "aws_cloudwatch_metric_alarm" "redis_replication_lag" {
  alarm_name          = "${var.name_prefix}-redis-replication-lag"
  namespace           = "AWS/ElastiCache"
  metric_name         = "ReplicationLag"
  statistic           = "Maximum"
  period              = var.alarm_period_seconds
  evaluation_periods  = var.alarm_eval_periods
  comparison_operator = "GreaterThanThreshold"
  threshold           = var.redis_replication_lag
  dimensions          = local.redis_dim
  alarm_actions       = local.cw_actions
  tags                = local.tags

  lifecycle {
    ignore_changes = all
  }

}

