resource "aws_elasticache_subnet_group" "redis" {
  name       = "${var.name_prefix}-redis-subnets"
  subnet_ids = module.vpc.database_subnets
}

resource "aws_elasticache_parameter_group" "redis" {
  name   = "${var.name_prefix}-redis-params"
  family = var.redis_family
  parameter {
    name  = "tcp-keepalive"
    value = "60"
  }

  # ---- Slow log tuning (useful for troubleshooting) ----
  # 10000 microseconds = 10ms; adjust if you want fewer/more entries
  parameter {
    name  = "slowlog-log-slower-than"
    value = "10000"
  }
  parameter {
    name  = "slowlog-max-len"
    value = "256"
  }
}

############################################
# CloudWatch Logs (365d) for Redis
############################################
resource "aws_cloudwatch_log_group" "redis_slow" {
  name              = "/aws/elasticache/${var.name_prefix}-redis/slow-log"
  retention_in_days = 365
  tags              = local.tags
}

# Optional: engine log (comment out if you don't want it)
resource "aws_cloudwatch_log_group" "redis_engine" {
  name              = "/aws/elasticache/${var.name_prefix}-redis/engine-log"
  retention_in_days = 365
  tags              = local.tags
}

resource "aws_elasticache_replication_group" "redis" {
  replication_group_id       = "${var.name_prefix}-redis-01"
  description                = "Redis for app"
  engine                     = "redis"
  engine_version             = "7.1"
  node_type                  = var.redis_node_type
  port                       = var.redis_port
  automatic_failover_enabled = true
  multi_az_enabled           = var.redis_multi_az
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  apply_immediately          = true
  snapshot_window 	     = var.redis_snapshot_window
  snapshot_retention_limit   = var.redis_snapshot_retention_limit

  # Use the BYOK KMS key ARN (set kms_byok_arn in prod.tfvars)
  kms_key_id = var.kms_byok_arn

  subnet_group_name    = aws_elasticache_subnet_group.redis.name
  security_group_ids   = [aws_security_group.redis.id]
  parameter_group_name = aws_elasticache_parameter_group.redis.name

  num_cache_clusters = var.redis_num_nodes

  # ---- Deliver logs to CloudWatch Logs ----
  log_delivery_configuration {
    destination_type = "cloudwatch-logs"
    destination      = aws_cloudwatch_log_group.redis_slow.name
    log_format       = "text"
    log_type         = "slow-log"
  }

  # Optional engine log
  log_delivery_configuration {
    destination_type = "cloudwatch-logs"
    destination      = aws_cloudwatch_log_group.redis_engine.name
    log_format       = "text"
    log_type         = "engine-log"
  }

  tags               = local.tags

#  lifecycle {
#    prevent_destroy = true
#    ignore_changes = [
#      apply_immediately,
#      auth_token_update_strategy,
#      description,
#      member_clusters,
#      parameter_group_name,
#      member_clusters,
#      num_cache_clusters,
#      tags,
#      tags_all,
#    ]
#  }

  lifecycle {
    ignore_changes = all
  }

}

