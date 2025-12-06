# === Environment: prod (me-central-1) ===
region         = "me-central-1"
us_east_1_region = "us-east-1"

name_prefix    = "ewec-prod"
project        = "EWEC"
environment    = "prod"
owner          = "Platform"

kms_byok_arn = "arn:aws:kms:me-central-1:035838344560:key/0664e9dc-d183-4851-8482-02d255c1f0cf"

vpc_cidr       = "192.168.0.0/20"
azs            = ["me-central-1a","me-central-1b"]
public_subnets = ["192.168.1.0/26","192.168.2.0/26"]
private_subnets = ["192.168.3.0/26","192.168.4.0/26"]
data_subnets   = ["192.168.5.0/26","192.168.6.0/26"]

# ALB + DNS
alb_logs_prefix = "alb"

# Access
alert_email    = "dhawal.modi@credencys.com"
#office_cidr    = "0.0.0.0/0"
office_cidr = [
  "117.247.91.177/32",
  "122.170.13.109/32",
  "49.36.69.132/32",
]
alb_ingress_cidrs = ["0.0.0.0/0"]

# EKS
eks_version        = "1.34"
eks_api_cidrs      = ["0.0.0.0/0"]
eks_ng_ewec_prod_desired     = 2
eks_ng_ewec_prod_min         = 2
eks_ng_ewec_prod_max         = 4
eks_instance_types = ["m7g.xlarge"]
eks_ami_type	   = "AL2023_ARM_64_STANDARD"

# RDS
db_instance_class       = "db.m6g.xlarge"
db_allocated_storage    = 128
db_name                 = "appdb"
db_user                 = "appuser"
#db_pass			= "e1I0Niqc4j2S"
db_port                 = 3306
db_multi_az             = true
db_backup_retention     = 7
db_engine_version       = "8.0"
db_family               = "mysql8.0"
db_major_engine_version = "8.0"

# Redis
redis_family     = "redis7"
redis_port       = 6379
redis_num_nodes  = 2
redis_node_type  = "cache.m5.large"
redis_multi_az   = true
redis_snapshot_window	= "01:00-02:00"
redis_snapshot_retention_limit	= 7

# EFS
efs_transition_to_ia = "AFTER_30_DAYS"

# ACM cert ARN (in me-central-1)
alb_certificate_arn = "arn:aws:acm:me-central-1:035838344560:certificate/3ef87d19-3cce-4387-a135-ddf24250cce5"

# ALB HTTPS / Domain
alb_ssl_policy      = "ELBSecurityPolicy-TLS13-1-2-2021-06"

# GuardDuty
enable_guardduty                 = true
guardduty_publishing_frequency   = "FIFTEEN_MINUTES"
enable_guardduty_sample_findings = true

malware_s3_bucket_name       = "ewec-prod-logs"
malware_s3_object_prefixes   = []                # e.g. ["uploads/", "incoming/"]
malware_s3_enable_tagging    = true


# Flow logs
flowlog_traffic_type = "ALL"

# Alarms - EKS CPU
eks_cpu_threshold     = 80         # percent
eks_cpu_period        = 300        # 5 min
eks_cpu_eval_periods  = 2

# Ingress host (leave "" to accept all hosts, or set to your domain)
ingress_host        = ""
alb_group_name      = "ewec-prod-shared-alb"
alb_healthcheck_path= "/"
alb_hostname        = ""


# ===== CloudWatch Alarms (prod) =====

# (Fill this after ALB exists; copy the ARN suffix "app/…/…")
alb_arn_suffix              = "k8s-ewecprodshared-3f008bcac0-986571404.me-central-1.elb.amazonaws.com"

# Global alarm timing
alarm_period_seconds        = 300                         # 5 minutes
alarm_eval_periods          = 3

# ALB thresholds
alb_5xx_threshold           = 5                           # total 5xx per period
alb_4xx_threshold           = 200                         # total 4xx per period
alb_latency_p95_ms          = 400                        # P95 target RT (ms)
alb_unhealthy_threshold     = 1

# EKS (ContainerInsights)
eks_container_restarts_threshold   = 5 

#kms
kms_disabled_key_threshold         = 1        # alert if key disabled (should be 0)
kms_failed_key_rotation_threshold  = 1        # <1 means rotation not enabled

# NAT Gateway thresholds
nat_error_port_allocation_threshold = 1
nat_dropped_packets_threshold       = 100

#RDS
rds_freeable_mb        = 512                 # MiB
rds_db_connections     = 200
rds_read_lat_ms        = 200                 # ms, converted to seconds in alarm
rds_write_lat_ms       = 200                 # ms, converted to seconds in alarm
rds_replica_lag        = 60                  # seconds (only if replicas exist)

# If used elsewhere in your RDS alarms:
rds_mem_eval_periods   = 3                   # existing var in alarms.tf
rds_mem_period         = 60                  # existing var in alarms.tf
rds_mem_threshold      = 536870912           # 512 MiB in bytes (if alarms.tf expects bytes)

# EKS (Container Insights – cluster wide)
eks_node_cpu_pct            = 85
eks_node_mem_pct            = 90
eks_pods_not_ready          = 5

# RDS thresholds
rds_cpu_pct                 = 80
rds_free_storage_mb         = 10240                       # 10 GB
rds_conn_high               = 200

# ElastiCache (Redis)
redis_cpu_pct               = 80
redis_freeable_mb           = 512
redis_evictions             = 0
redis_replication_lag       = 2
redis_curr_conn             = 500
redis_swap_usage_mb         = 100

# EFS
efs_burst_credit_min        = 10000000000                 # 10e9 bytes
efs_percent_io_limit        = 90
efs_client_conn_high        = 200

# KMS (per-key)
kms_throttle_count          = 0

launch_template_id = null
