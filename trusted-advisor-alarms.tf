########################################################
# Trusted Advisor Alarms (no EventBridge)
# Triggers SNS if any Red/Yellow resources > 0
########################################################

# Regions you care about for TA metric dimension
# (TA emits the "Region" dimension; use one or many)
variable "ta_regions" {
  description = "Regions to alarm for Trusted Advisor metrics"
  type        = list(string)
  default     = ["me-central-1"] # add others if needed
}

# Red (critical) resources > 0
resource "aws_cloudwatch_metric_alarm" "ta_red_resources" {
  for_each = toset(var.ta_regions)

  alarm_name          = "${var.name_prefix}-ta-red-${each.key}"
  alarm_description   = "Trusted Advisor RED issues detected in ${each.key}"
  namespace           = "AWS/TrustedAdvisor"
  metric_name         = "RedResources"
  statistic           = "Maximum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"

  dimensions = {
    Region = each.key
  }

  alarm_actions      = [aws_sns_topic.alerts.arn]
  ok_actions         = [aws_sns_topic.alerts.arn]
  treat_missing_data = "notBreaching"
}

# Yellow (warning) resources > 0
resource "aws_cloudwatch_metric_alarm" "ta_yellow_resources" {
  for_each = toset(var.ta_regions)

  alarm_name          = "${var.name_prefix}-ta-yellow-${each.key}"
  alarm_description   = "Trusted Advisor YELLOW issues detected in ${each.key}"
  namespace           = "AWS/TrustedAdvisor"
  metric_name         = "YellowResources"
  statistic           = "Maximum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"

  dimensions = {
    Region = each.key
  }

  alarm_actions      = [aws_sns_topic.alerts.arn]
  ok_actions         = [aws_sns_topic.alerts.arn]
  treat_missing_data = "notBreaching"
}

