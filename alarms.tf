############################################
# General Alarms (wired to SNS)
############################################
# Assumes:
# - module.db.db_instance_identifier is your RDS instance id
# - aws_sns_topic.alerts exists (org-controls.tf)
# - local.cw_actions = [aws_sns_topic.alerts.arn] defined once (e.g., in alarms-alb.tf)
# - local.tags is your common tags
#
# Variables expected (already present in your code):
# - var.rds_mem_eval_periods
# - var.rds_mem_period
# - var.rds_mem_threshold

# Alarm: Low FreeableMemory on RDS
resource "aws_cloudwatch_metric_alarm" "rds_low_mem" {
  alarm_name          = "${var.name_prefix}-rds-low-memory"
  namespace           = "AWS/RDS"
  metric_name         = "FreeableMemory"
  statistic           = "Average"
  period              = var.rds_mem_period
  evaluation_periods  = var.rds_mem_eval_periods
  comparison_operator = "LessThanThreshold"
  threshold           = var.rds_mem_threshold
  alarm_description   = "Alarm when RDS freeable memory < threshold"

  dimensions = {
    DBInstanceIdentifier = module.db.db_instance_identifier
  }

  # Wire to SNS (keep this consistent across all alarms)
  alarm_actions             = local.cw_actions
  ok_actions                = local.cw_actions
  insufficient_data_actions = local.cw_actions

  # Avoid flapping if metric is occasionally missing
  treat_missing_data = "notBreaching"

  tags = local.tags
}
