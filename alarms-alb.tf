############################################
# ALB CloudWatch Alarms (wired to SNS)
############################################

locals {
  cw_actions = [aws_sns_topic.alerts.arn]
}

############################################
# 5xx errors (sum over the period)
############################################
resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  count               = var.alb_arn_suffix == "" ? 0 : 1
  alarm_name          = "${var.name_prefix}-alb-5xx"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HTTPCode_ELB_5XX_Count"
  statistic           = "Sum"
  period              = var.alarm_period_seconds
  evaluation_periods  = var.alarm_eval_periods
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = var.alb_5xx_threshold
  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }

  # Wire to SNS
  alarm_actions             = local.cw_actions
  ok_actions                = local.cw_actions
  insufficient_data_actions = local.cw_actions

  # Optional behavior for sparse metrics
  treat_missing_data = "notBreaching"

  tags = local.tags
}

############################################
# 4xx errors (sum over the period)
############################################
resource "aws_cloudwatch_metric_alarm" "alb_4xx" {
  count               = var.alb_arn_suffix == "" ? 0 : 1
  alarm_name          = "${var.name_prefix}-alb-4xx"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HTTPCode_ELB_4XX_Count"
  statistic           = "Sum"
  period              = var.alarm_period_seconds
  evaluation_periods  = var.alarm_eval_periods
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = var.alb_4xx_threshold
  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }

  alarm_actions             = local.cw_actions
  ok_actions                = local.cw_actions
  insufficient_data_actions = local.cw_actions

  treat_missing_data = "notBreaching"

  tags = local.tags
}

############################################
# Unhealthy targets (max over the period)
############################################
resource "aws_cloudwatch_metric_alarm" "alb_unhealthy" {
  count               = var.alb_arn_suffix == "" ? 0 : 1
  alarm_name          = "${var.name_prefix}-alb-unhealthy-targets"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "UnHealthyHostCount"
  statistic           = "Maximum"
  period              = var.alarm_period_seconds
  evaluation_periods  = var.alarm_eval_periods
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = var.alb_unhealthy_threshold
  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }

  alarm_actions             = local.cw_actions
  ok_actions                = local.cw_actions
  insufficient_data_actions = local.cw_actions

  treat_missing_data = "notBreaching"

  tags = local.tags
}

############################################
# P95 target response time (seconds)
############################################
resource "aws_cloudwatch_metric_alarm" "alb_latency_p95" {
  count               = var.alb_arn_suffix == "" ? 0 : 1
  alarm_name          = "${var.name_prefix}-alb-latency-p95"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "TargetResponseTime"
  extended_statistic  = "p95"
  period              = var.alarm_period_seconds
  evaluation_periods  = var.alarm_eval_periods
  comparison_operator = "GreaterThanThreshold"
  # var.alb_latency_p95_ms is in ms; CloudWatch TargetResponseTime is seconds
  threshold           = var.alb_latency_p95_ms / 1000.0
  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }

  alarm_actions             = local.cw_actions
  ok_actions                = local.cw_actions
  insufficient_data_actions = local.cw_actions

  treat_missing_data = "notBreaching"

  tags = local.tags
}
