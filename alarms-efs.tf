############################################
# EFS CloudWatch Alarms (wired to SNS)
############################################

# Looks up the current EFS filesystem from your TF resource.
# If you're using a module for EFS, replace with the correct reference.
data "aws_efs_file_system" "selected" {
  file_system_id = aws_efs_file_system.this.id
}

############################################
# Burst credits low
############################################
resource "aws_cloudwatch_metric_alarm" "efs_burst_credits_low" {
  alarm_name          = "${var.name_prefix}-efs-burst-credits-low"
  namespace           = "AWS/EFS"
  metric_name         = "BurstCreditBalance"
  statistic           = "Minimum"
  period              = var.alarm_period_seconds
  evaluation_periods  = var.alarm_eval_periods
  comparison_operator = "LessThanThreshold"
  threshold           = var.efs_burst_credit_min

  dimensions = {
    FileSystemId = data.aws_efs_file_system.selected.id
  }

  # Wire to SNS
  alarm_actions             = local.cw_actions
  ok_actions                = local.cw_actions
  insufficient_data_actions = local.cw_actions

  # Prevent noise when metric is missing
  treat_missing_data = "notBreaching"

  tags = local.tags
}

############################################
# Percent IO limit (when using EFS bursting)
############################################
resource "aws_cloudwatch_metric_alarm" "efs_percent_io_limit" {
  alarm_name          = "${var.name_prefix}-efs-percent-io-limit"
  namespace           = "AWS/EFS"
  metric_name         = "PercentIOLimit"
  statistic           = "Average"
  period              = var.alarm_period_seconds
  evaluation_periods  = var.alarm_eval_periods
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = var.efs_percent_io_limit

  dimensions = {
    FileSystemId = data.aws_efs_file_system.selected.id
  }

  alarm_actions             = local.cw_actions
  ok_actions                = local.cw_actions
  insufficient_data_actions = local.cw_actions

  treat_missing_data = "notBreaching"

  tags = local.tags
}

############################################
# Client connections high (unusual spikes)
############################################
resource "aws_cloudwatch_metric_alarm" "efs_client_conn_high" {
  alarm_name          = "${var.name_prefix}-efs-client-connections-high"
  namespace           = "AWS/EFS"
  metric_name         = "ClientConnections"
  statistic           = "Average"
  period              = var.alarm_period_seconds
  evaluation_periods  = var.alarm_eval_periods
  comparison_operator = "GreaterThanThreshold"
  threshold           = var.efs_client_conn_high

  dimensions = {
    FileSystemId = data.aws_efs_file_system.selected.id
  }

  alarm_actions             = local.cw_actions
  ok_actions                = local.cw_actions
  insufficient_data_actions = local.cw_actions

  treat_missing_data = "notBreaching"

  tags = local.tags
}
