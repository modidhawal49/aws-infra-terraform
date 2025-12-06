# alarms-eks-containerinsights.tf
# EKS cluster health alarms using AWS/ContainerInsights metrics (no SEARCH/metric math)

locals {
  eks_ns  = "AWS/ContainerInsights"
  cluster = module.eks.cluster_name
}

############################################
# 1) Pods Not Ready (cluster-wide)
############################################
resource "aws_cloudwatch_metric_alarm" "eks_pods_not_ready" {
  alarm_name          = "${var.name_prefix}-eks-pods-not-ready"
  namespace           = local.eks_ns
  metric_name         = "pod_status_not_ready"
  statistic           = "Sum"
  period              = var.alarm_period_seconds
  evaluation_periods  = var.alarm_eval_periods
  comparison_operator = "GreaterThanThreshold"
  threshold           = 0
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = local.cluster
  }

  alarm_actions             = local.cw_actions
  ok_actions                = local.cw_actions
  insufficient_data_actions = local.cw_actions

  tags = local.tags
}

############################################
# 2) Container Restarts (cluster-wide)
############################################
resource "aws_cloudwatch_metric_alarm" "eks_container_restarts" {
  alarm_name          = "${var.name_prefix}-eks-container-restarts"
  namespace           = local.eks_ns
  metric_name         = "container_restart_count" # alternative: pod_number_of_container_restarts
  statistic           = "Sum"
  period              = var.alarm_period_seconds
  evaluation_periods  = var.alarm_eval_periods
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = var.eks_container_restarts_threshold
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = local.cluster
  }

  alarm_actions             = local.cw_actions
  ok_actions                = local.cw_actions
  insufficient_data_actions = local.cw_actions

  tags = local.tags
}

############################################
# 3) Failed Nodes (cluster-wide)
############################################
resource "aws_cloudwatch_metric_alarm" "eks_failed_nodes" {
  alarm_name          = "${var.name_prefix}-eks-failed-nodes"
  namespace           = local.eks_ns
  metric_name         = "node_status"
  statistic           = "Maximum"
  period              = var.alarm_period_seconds
  evaluation_periods  = var.alarm_eval_periods
  comparison_operator = "LessThanThreshold"
  threshold           = 1
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = local.cluster
    Node        = "All" # metric aggregate across nodes
  }

  alarm_actions             = local.cw_actions
  ok_actions                = local.cw_actions
  insufficient_data_actions = local.cw_actions

  tags = local.tags
}

############################################
# 4) Disk Pressure (kube node condition)
############################################
resource "aws_cloudwatch_metric_alarm" "eks_node_disk_pressure" {
  alarm_name          = "${var.name_prefix}-eks-node-disk-pressure"
  namespace           = local.eks_ns
  metric_name         = "node_status_condition" # 1 if condition true, else 0
  statistic           = "Maximum"
  period              = var.alarm_period_seconds
  evaluation_periods  = var.alarm_eval_periods
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = 1
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = local.cluster
    Condition   = "DiskPressure"
    Status      = "true"
  }

  alarm_actions             = local.cw_actions
  ok_actions                = local.cw_actions
  insufficient_data_actions = local.cw_actions

  tags = local.tags
}

############################################
# 5) Memory Pressure (kube node condition)
############################################
resource "aws_cloudwatch_metric_alarm" "eks_node_memory_pressure" {
  alarm_name          = "${var.name_prefix}-eks-node-memory-pressure"
  namespace           = local.eks_ns
  metric_name         = "node_status_condition"
  statistic           = "Maximum"
  period              = var.alarm_period_seconds
  evaluation_periods  = var.alarm_eval_periods
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = 1
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = local.cluster
    Condition   = "MemoryPressure"
    Status      = "true"
  }

  alarm_actions             = local.cw_actions
  ok_actions                = local.cw_actions
  insufficient_data_actions = local.cw_actions

  tags = local.tags
}

############################################
# 6) PID Pressure (kube node condition)
############################################
resource "aws_cloudwatch_metric_alarm" "eks_node_pid_pressure" {
  alarm_name          = "${var.name_prefix}-eks-node-pid-pressure"
  namespace           = local.eks_ns
  metric_name         = "node_status_condition"
  statistic           = "Maximum"
  period              = var.alarm_period_seconds
  evaluation_periods  = var.alarm_eval_periods
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = 1
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = local.cluster
    Condition   = "PIDPressure"
    Status      = "true"
  }

  alarm_actions             = local.cw_actions
  ok_actions                = local.cw_actions
  insufficient_data_actions = local.cw_actions

  tags = local.tags
}

############################################
# 7) Node Ready == false (any node)
############################################
resource "aws_cloudwatch_metric_alarm" "eks_node_not_ready" {
  alarm_name          = "${var.name_prefix}-eks-node-not-ready"
  namespace           = local.eks_ns
  metric_name         = "node_status_condition"
  statistic           = "Maximum"
  period              = var.alarm_period_seconds
  evaluation_periods  = var.alarm_eval_periods
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = 1
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = local.cluster
    Condition   = "Ready"
    Status      = "false"
  }

  alarm_actions             = local.cw_actions
  ok_actions                = local.cw_actions
  insufficient_data_actions = local.cw_actions

  tags = local.tags
}

