data "aws_kms_key" "byok_for_alarms" {
  key_id = var.kms_byok_arn
}

# Single BYOK key -> single alarm
locals {
  kms_key_ids = toset([data.aws_kms_key.byok_for_alarms.key_id]) # this is the UUID, e.g. d6fe2485-...
}

resource "aws_cloudwatch_metric_alarm" "kms_throttles" {
  for_each            = local.kms_key_ids

  alarm_name          = "${var.name_prefix}-kms-${each.value}-throttles"
  alarm_description   = "KMS throttle count > 0 for key ${each.value} (BYOK)."
  namespace           = "AWS/KMS"
  metric_name         = "ThrottleCount"
  statistic           = "Sum"
  period              = var.alarm_period_seconds
  evaluation_periods  = var.alarm_eval_periods
  comparison_operator = "GreaterThanThreshold"
  threshold           = var.kms_throttle_count

  # IMPORTANT: use the UUID, not the ARN
  dimensions = { KeyId = each.value }

  treat_missing_data  = "missing"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  insufficient_data_actions = []

  tags = local.tags
}
