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

output "efs_file_system_id" {
  value = aws_efs_file_system.this.id
}

output "rds_master_secret_arn" {
  value = module.db.db_instance_master_user_secret_arn
}

############################################
# (Optional) Helpful Outputs
############################################
output "efs_mount_targets" {
  description = "Map of subnet_id => mount target ID"
  value       = { for k, v in aws_efs_mount_target.mt : v.subnet_id => v.id }
}

output "efs_ap_prod" {
  description = "EFS Access Point ID for /prod"
  value       = aws_efs_access_point.prod.id
}

output "db_master_user_secret_arn" {
  description = "Secrets Manager ARN holding the RDS master user password"
  value       = try(module.db.db_instance_master_user_secret_arn, module.db.master_user_secret_arn)
}
