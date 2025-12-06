############################################################
# KMS alarms with static for_each keys (safe for planning)
############################################################
# Assumes:
# - aws_kms_key.db, aws_kms_key.efs exist (adjust if names differ)
# - local.cw_actions = [aws_sns_topic.alerts.arn]
# - local.tags for tagging
#
# Variables expected:
# - var.kms_disabled_key_threshold (usually 1)
# - var.kms_failed_key_rotation_threshold (usually 1)

# 1) Declare a static list of logical keys you want to monitor
locals {
  kms_alarm_keys = toset(["db", "efs", "sns"])
}

# 2) Map those logical keys to the actual KMS KeyIds (values can be unknown until apply)
locals {
  kms_key_ids = {
    db  = aws_kms_key.db.key_id
    efs = aws_kms_key.efs.key_id
    sns = aws_kms_key.sns.key_id
  }
}

# 3) Common KMS alarm dimensions per key
locals {
  kms_dimensions = {
    for k in local.kms_alarm_keys :
    k => { KeyId = local.kms_key_ids[k] }
  }
}

############################################
# Key Disabled (should be 0)
############################################
resource "aws_cloudwatch_metric_alarm" "kms_key_disabled" {
  for_each            = local.kms_dimensions
  alarm_name          = "${var.name_prefix}-kms-${each.key}-key-disabled"
  namespace           = "AWS/KMS"
  metric_name         = "DisabledKey"
  statistic           = "Maximum"
  period              = var.alarm_period_seconds
  evaluation_periods  = var.alarm_eval_periods
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = var.kms_disabled_key_threshold

  dimensions = each.value

  alarm_actions             = local.cw_actions
  ok_actions                = local.cw_actions
  insufficient_data_actions = local.cw_actions
  treat_missing_data        = "notBreaching"

  tags = local.tags
}

############################################
# Failed Key Rotation (should be 0)
############################################
resource "aws_cloudwatch_metric_alarm" "kms_failed_key_rotation" {
  for_each            = local.kms_dimensions
  alarm_name          = "${var.name_prefix}-kms-${each.key}-failed-rotation"
  namespace           = "AWS/KMS"
  metric_name         = "KeyRotationEnabled"
  statistic           = "Minimum"
  period              = var.alarm_period_seconds
  evaluation_periods  = var.alarm_eval_periods
  comparison_operator = "LessThanThreshold"
  threshold           = var.kms_failed_key_rotation_threshold

  dimensions = each.value

  alarm_actions             = local.cw_actions
  ok_actions                = local.cw_actions
  insufficient_data_actions = local.cw_actions
  treat_missing_data        = "notBreaching"

  tags = local.tags
}

