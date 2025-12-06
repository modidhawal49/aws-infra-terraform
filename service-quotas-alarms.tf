############################################
# Service Quotas → CloudWatch alarms
# Each alarm uses aws_sns_topic.alerts.arn
############################################

# ---------- Helper: Common dimensions ----------
locals {
  usage_namespace = "AWS/Usage"

  quota_items = [
    # Elastic IPs per region
    {
      id           = "eips"
      desc         = "Elastic IPs in region"
      service_code = "ec2"
      quota_code   = "L-0263D0A3" # Elastic IP addresses
      dimensions   = {
        Class    = "None"
        Resource = "vpc"
        Service  = "EC2"
        Type     = "ElasticIPs"
      }
    },

    # Application Load Balancers per region
    {
      id           = "albs"
      desc         = "Application Load Balancers in region"
      service_code = "elasticloadbalancing"
      quota_code   = "L-53DA6B97"
      dimensions   = {
        Class    = "None"
        Resource = "loadbalancers"
        Service  = "ELB"
        Type     = "application"
      }
    },

    # Network Load Balancers per region
    {
      id           = "nlbs"
      desc         = "Network Load Balancers in region"
      service_code = "elasticloadbalancing"
      quota_code   = "L-69A177A2"
      dimensions   = {
        Class    = "None"
        Resource = "loadbalancers"
        Service  = "ELB"
        Type     = "network"
      }
    },

    # Security Groups per VPC
    {
      id           = "sgs-per-vpc"
      desc         = "Security Groups per VPC"
      service_code = "vpc"
      quota_code   = "L-0EA8095F"
      dimensions   = {
        Class    = "None"
        Resource = "vpc"
        Service  = "VPC"
        Type     = "security-groups"
      }
    },

    # VPCs per region
    {
      id           = "vpcs"
      desc         = "VPCs in region"
      service_code = "vpc"
      quota_code   = "L-F678F1CE"
      dimensions   = {
        Class    = "None"
        Resource = "vpc"
        Service  = "VPC"
        Type     = "vpc"
      }
    },
  ]
}

# ---------- Look up region/account ----------
# ---------- Pull quota values ----------
data "aws_servicequotas_service_quota" "quota" {
  for_each     = { for q in local.quota_items : q.id => q }
  service_code = each.value.service_code
  quota_code   = each.value.quota_code
}

# ---------- Thresholds (85% of quota by default) ----------
variable "quota_alarm_percent" {
  type        = number
  default     = 0.85
  description = "Alarm when usage >= percent of the quota"
}

locals {
  quota_thresholds = {
    for id, q in data.aws_servicequotas_service_quota.quota :
    id => floor(tonumber(q.value) * var.quota_alarm_percent)
  }
}

# ---------- CloudWatch alarms ----------
resource "aws_cloudwatch_metric_alarm" "quota_alarms" {
  for_each = { for q in local.quota_items : q.id => q }

  alarm_name          = "${var.name_prefix}-${each.value.id}-near-limit"
  alarm_description   = "${each.value.desc} near limit in ${data.aws_region.current.name} (>= ${local.quota_thresholds[each.key]} of ${data.aws_servicequotas_service_quota.quota[each.key].value})"
  namespace           = local.usage_namespace
  metric_name         = "ResourceCount"
  statistic           = "Maximum"
  period              = 300
  evaluation_periods  = 1
  datapoints_to_alarm = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = local.quota_thresholds[each.key]

  # CloudWatch dimensions for each quota
  dimensions = each.value.dimensions

  treat_missing_data = "notBreaching"

  # 👉 Directly wired to your SNS topic
  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]
}
