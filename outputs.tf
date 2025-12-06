output "vpc_id" {
  value = module.vpc.vpc_id
}

output "public_subnets" {
  value = module.vpc.public_subnets
}

output "app_private_subnets" {
  value = module.vpc.private_subnets
}

output "data_private_subnets" {
  value = module.vpc.database_subnets
}

output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "eks_oidc_provider_arn" {
  value = module.eks.oidc_provider_arn
}

output "rds_endpoint" {
  value = module.db.db_instance_endpoint
}

output "redis_primary_endpoint" {
  value = aws_elasticache_replication_group.redis.primary_endpoint_address
}

output "ecr_repo" {
  value = aws_ecr_repository.app.repository_url
}

output "secretsmanager_endpoint_id" {
  value = aws_vpc_endpoint.secretsmanager.id
}

############################################
# Controller-managed ALB outputs
############################################

output "efs_id" {
  value = aws_efs_file_system.this.id
}

output "efs_dev_access_point_arn" {
  value = aws_efs_access_point.dev.arn
}

output "efs_file_system_id" {
  value = aws_efs_file_system.this.id
}

output "efs_mount_target_subnet_map" {
  description = "AZ => subnet used for EFS mount target"
  value       = local.private_subnet_per_az
}

output "efs_access_point_dev_id" {
  value = aws_efs_access_point.dev.id
}

output "rds_master_secret_arn" {
  value = module.db.db_instance_master_user_secret_arn
}

output "db_master_user_secret_arn" {
  description = "Secrets Manager ARN holding the RDS master user password"
  value       = try(module.db.db_instance_master_user_secret_arn, module.db.master_user_secret_arn)
}

