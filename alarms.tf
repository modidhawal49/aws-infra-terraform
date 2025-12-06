# Alarm: Low FreeableMemory on RDS
resource "aws_cloudwatch_metric_alarm" "rds_low_mem" {
  alarm_name          = "${var.name_prefix}-rds-low-memory"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = var.rds_mem_eval_periods
  metric_name         = "FreeableMemory"
  namespace           = "AWS/RDS"
  period              = var.rds_mem_period
  statistic           = "Average"
  threshold           = var.rds_mem_threshold
  alarm_description   = "Alarm when RDS freeable memory < threshold"

  dimensions = {
    DBInstanceIdentifier = module.db.db_instance_identifier
  }

  alarm_actions = [aws_sns_topic.alerts.arn]

  tags = local.tags
}

