# -------------------------
# Global
# -------------------------
variable "region" {
  type = string
}

variable "name_prefix" {
  type = string
}

variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "owner" {
  type = string
}

# -------------------------
# DNS / ALB
# -------------------------
#variable "hosted_zone_id" {
#  type = string
#}

variable "alb_logs_prefix" {
  type    = string
  default = "alb"
}

variable "alb_ingress_cidrs" {
  type    = list(string)
  default = ["0.0.0.0/0"]
}

# -------------------------
# Networking
# -------------------------
variable "vpc_cidr" {
  type = string
}

variable "azs" {
  type = list(string)
}

variable "public_subnets" {
  type = list(string)
}

variable "private_subnets" {
  type = list(string)
}

variable "data_subnets" {
  type = list(string)
}

# -------------------------
# EKS
# -------------------------
variable "eks_version" {
  type = string
}

variable "eks_api_cidrs" {
  type = list(string)
}

variable "eks_ng_ewec_nonprod_desired" {
  type = number
}

variable "eks_ng_ewec_nonprod_min" {
  type = number
}

variable "eks_ng_ewec_nonprod_max" {
  type = number
}

variable "eks_instance_types" {
  type = list(string)
}

variable "eks_ami_type" {
  type = string
}

variable "deploy_addons" {
  type    = bool
  default = true
}

# -------------------------
# Alerts / Access
# -------------------------
variable "alert_email" {
  type = string
}

variable "office_cidr" {
  type = string
}

# -------------------------
# Provider Aliases
# -------------------------
variable "us_east_1_region" {
  type    = string
  default = "us-east-1"
}

# -------------------------
# RDS (MySQL)
# -------------------------
variable "db_instance_class" {
  type = string
}

variable "db_allocated_storage" {
  type = number
}

variable "db_name" {
  type = string
}

variable "db_user" {
  type = string
}

#variable "db_pass" {
#  type = string
#}

variable "db_port" {
  type    = number
  default = 3306
}

variable "db_multi_az" {
  type    = bool
  default = true
}

variable "db_backup_retention" {
  type    = number
  default = 7
}

variable "db_engine_version" {
  type    = string
  default = "8.0"
}

variable "db_family" {
  type    = string
  default = "mysql8.0"
}

variable "db_major_engine_version" {
  type    = string
  default = "8.0"
}

# -------------------------
# Redis (ElastiCache)
# -------------------------
variable "redis_family" {
  type    = string
  default = "redis7"
}

variable "redis_port" {
  type    = number
  default = 6379
}

variable "redis_num_nodes" {
  type = number
}

variable "redis_node_type" {
  type    = string
  default = "cache.t3.medium"
}

# -------------------------
# EFS
# -------------------------
variable "efs_transition_to_ia" {
  type    = string
  default = "AFTER_30_DAYS"
}

variable "alb_ssl_policy" {
  type    = string
  default = "ELBSecurityPolicy-TLS13-1-2-2021-06"
}

variable "alb_certificate_arn" {
  type = string
}

variable "wafv2_acl_arn" {
  type    = string
  default = ""
}


############################
# GuardDuty variables
############################
variable "enable_guardduty" {
  type    = bool
  default = true
}
variable "guardduty_publishing_frequency" {
  type    = string
  default = "FIFTEEN_MINUTES"
}
variable "enable_guardduty_sample_findings" {
  type    = bool
  default = false
}



# Flow logs
variable "flowlog_traffic_type" {
  description = "Traffic type to capture for VPC flow logs"
  type        = string
  default     = "ALL"
}

# Alarms - EKS CPU
variable "eks_cpu_threshold" {
  description = "CPU % threshold for EKS nodes"
  type        = number
}
variable "eks_cpu_period" {
  description = "Period (seconds) for EKS CPU alarm"
  type        = number
}
variable "eks_cpu_eval_periods" {
  description = "Evaluation periods for EKS CPU alarm"
  type        = number
}

# Alarms - RDS Memory
variable "rds_mem_threshold" {
  description = "Freeable memory threshold (bytes) for RDS"
  type        = number
}
variable "rds_mem_period" {
  description = "Period (seconds) for RDS memory alarm"
  type        = number
}
variable "rds_mem_eval_periods" {
  description = "Evaluation periods for RDS memory alarm"
  type        = number
}

# Redis Multi-AZ
variable "redis_multi_az" {
  description = "Enable Multi-AZ for Redis (ElastiCache)"
  type        = bool
  default     = true
}


# -------------------------
# Ingress / ALB Controller
# -------------------------

# Optional hostname for ingress rule (matches ACM cert).
# Leave "" to match all hosts (wildcard * rule).
variable "ingress_host" {
  description = "Hostname for the Ingress rule (e.g. app.nonprod.example.com). Leave empty for wildcard host."
  type        = string
  default     = ""
}

# Group name ensures ALB is reused across multiple ingresses
variable "alb_group_name" {
  description = "ALB group.name annotation value to keep a stable ALB across deployments"
  type        = string
  default     = "ewec-nonprod-shared-alb"
}

# Healthcheck path for ALB target group
variable "alb_healthcheck_path" {
  description = "Path used by ALB for health checks"
  type        = string
  default     = "/"
}

# Optional hostname for ExternalDNS (CNAME to ALB)
variable "alb_hostname" {
  description = "DNS hostname for ExternalDNS (CNAME to ALB). Leave empty if not using ExternalDNS."
  type        = string
  default     = ""
}



##############################
# CloudWatch Alarm Variables
##############################

# ALB
variable "alb_arn_suffix" {
  description = "ALB ARN suffix (e.g., app/k8s-namespace-ingress-abc/1234567890abcdef). Leave empty to skip ALB alarms."
  type        = string
  default     = ""
}

# Global alarm timing
variable "alarm_period_seconds" {
  description = "Evaluation period for metrics (seconds)"
  type        = number
  default     = 300
}

variable "alarm_eval_periods" {
  description = "Number of periods to evaluate before firing alarm"
  type        = number
  default     = 3
}

# ALB thresholds
variable "alb_5xx_threshold" {
  type    = number
  default = 5
}

variable "alb_4xx_threshold" {
  type    = number
  default = 200
}

variable "alb_latency_p95_ms" {
  description = "P95 TargetResponseTime threshold in ms"
  type        = number
  default     = 1500
}

# NAT Gateway thresholds
variable "nat_error_port_alloc_threshold" {
  type    = number
  default = 0
}

variable "nat_dropped_packets_threshold" {
  type    = number
  default = 0
}

# EKS thresholds (Container Insights)
variable "eks_node_cpu_pct" {
  type    = number
  default = 85
}

variable "eks_node_mem_pct" {
  type    = number
  default = 90
}

variable "eks_pods_not_ready" {
  type    = number
  default = 5
}

# RDS thresholds
variable "rds_cpu_pct" {
  type    = number
  default = 80
}

variable "rds_free_storage_mb" {
  type    = number
  default = 10240
}

variable "rds_conn_high" {
  type    = number
  default = 200
}

# Redis thresholds
variable "redis_cpu_pct" {
  type    = number
  default = 80
}

variable "redis_freeable_mb" {
  type    = number
  default = 512
}

variable "redis_evictions" {
  type    = number
  default = 0
}

variable "redis_replication_lag" {
  type    = number
  default = 2
}

# EFS thresholds
variable "efs_burst_credit_min" {
  description = "Minimum BurstCreditBalance in bytes"
  type        = number
  default     = 10000000000
}

variable "efs_percent_io_limit" {
  type    = number
  default = 90
}

variable "efs_client_conn_high" {
  type    = number
  default = 200
}

# KMS thresholds
variable "kms_throttle_count" {
  type    = number
  default = 0
}

variable "appmesh_controller_version" {
  description = "App Mesh controller chart version"
  type        = string
  default     = "1.11.0"
}

variable "ta_region" {
  description = "Trusted Advisor metrics Region dimension to alarm on"
  type        = string
  default     = "me-central-1"
}

variable "kms_byok_arn" {
  description = "Customer-managed BYOK KMS key ARN for all encryptions"
  type        = string
}

variable "create_k8s_ingress" {
  type    = bool
  default = false
}
