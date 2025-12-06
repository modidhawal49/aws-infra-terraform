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

  # Use the BYOK KMS key ARN (set kms_byok_arn in prod.tfvars)
  kms_key_id = data.aws_kms_key.byok.arn

  subnet_group_name    = aws_elasticache_subnet_group.redis.name
  security_group_ids   = [aws_security_group.redis.id]
  parameter_group_name = aws_elasticache_parameter_group.redis.name

  num_cache_clusters = var.redis_num_nodes # 2 = primary+replica across AZs
  tags               = local.tags

  lifecycle {
    ignore_changes = all
  }

}

