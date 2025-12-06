# alarms-eks-containerinsights.tf
# EKS cluster health alarms using AWS/ContainerInsights metrics (no SEARCH/metric math)

locals {
  eks_ns  = "AWS/ContainerInsights"
  cluster = module.eks.cluster_name
}

# 1) Pods Not Ready (cluster-wide)
resource "aws_cloudwatch_metric_alarm" "eks_pods_not_ready" {
  alarm_name          = "${var.name_prefix}-eks-pods-not-ready"
  namespace           = local.eks_ns
  metric_name         = "pod_status_not_ready"
  statistic           = "Sum"
  period              = var.alarm_period_seconds
  evaluation_periods  = var.alarm_eval_periods
  comparison_operator = "GreaterThanThreshold"
  threshold           = var.eks_pods_not_ready
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = local.cluster
    # Some environments publish by ClusterName only; others include Namespace.
    # If you later see a 'missing dimension' error, we can loop namespaces.
  }

  alarm_actions = local.cw_actions
  tags          = local.tags
}

# 2) Container Restarts (cluster-wide)
resource "aws_cloudwatch_metric_alarm" "eks_container_restarts" {
  count = 0
  alarm_name          = "${var.name_prefix}-eks-container-restarts"
  namespace           = local.eks_ns
  metric_name         = "pod_number_of_container_restarts"
  statistic           = "Sum"
  period              = var.alarm_period_seconds
  evaluation_periods  = var.alarm_eval_periods
  comparison_operator = "GreaterThanThreshold"
  threshold           = 10 # tweak in nonprod.tfvars if you want this configurable
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = local.cluster
  }

  alarm_actions = local.cw_actions
  tags          = local.tags
}

# 3) Failed Nodes (cluster-wide)
resource "aws_cloudwatch_metric_alarm" "eks_failed_nodes" {
  count = 0
  alarm_name          = "${var.name_prefix}-eks-failed-nodes"
  namespace           = local.eks_ns
  metric_name         = "cluster_failed_node_count"
  statistic           = "Maximum"
  period              = var.alarm_period_seconds
  evaluation_periods  = var.alarm_eval_periods
  comparison_operator = "GreaterThanThreshold"
  threshold           = 0
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = local.cluster
  }

  alarm_actions = local.cw_actions
  tags          = local.tags
}

