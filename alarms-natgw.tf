# alarms-natgw.tf

data "aws_nat_gateways" "this" {
  filter {
    name   = "vpc-id"
    values = [module.vpc.vpc_id]
  }
}

locals {
  natgw_ids = toset(data.aws_nat_gateways.this.ids)
}

resource "aws_cloudwatch_metric_alarm" "nat_error_port_alloc" {
  for_each            = local.natgw_ids
  alarm_name          = "${var.name_prefix}-nat-${each.value}-err-port-alloc"
  namespace           = "AWS/NATGateway"
  metric_name         = "ErrorPortAllocation"
  statistic           = "Sum"
  period              = var.alarm_period_seconds
  evaluation_periods  = var.alarm_eval_periods
  comparison_operator = "GreaterThanThreshold"
  threshold           = var.nat_error_port_alloc_threshold
  dimensions          = { NatGatewayId = each.value }
  alarm_actions       = [aws_sns_topic.alerts.arn]
  tags                = local.tags
}

resource "aws_cloudwatch_metric_alarm" "nat_packets_dropped" {
  for_each            = local.natgw_ids
  alarm_name          = "${var.name_prefix}-nat-${each.value}-dropped"
  namespace           = "AWS/NATGateway"
  metric_name         = "PacketsDroppedCount"
  statistic           = "Sum"
  period              = var.alarm_period_seconds
  evaluation_periods  = var.alarm_eval_periods
  comparison_operator = "GreaterThanThreshold"
  threshold           = var.nat_dropped_packets_threshold
  dimensions          = { NatGatewayId = each.value }
  alarm_actions       = [aws_sns_topic.alerts.arn]
  tags                = local.tags
}

