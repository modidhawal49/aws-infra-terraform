module "db" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 6.5"

  identifier            = "${var.name_prefix}-mysql-01"
  engine                = "mysql"
  engine_version        = var.db_engine_version
  family                = var.db_family
  major_engine_version  = var.db_major_engine_version
  instance_class        = var.db_instance_class
  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = 512

  # Apply changes ASAP to non-disruptive settings (like backup window/retention)
  apply_immediately   = true
  deletion_protection = true

  db_name  = var.db_name
  username = var.db_user
  #password = var.db_pass
  manage_master_user_password   = true
  master_user_secret_kms_key_id = var.kms_byok_arn

  db_subnet_group_name   = module.vpc.database_subnet_group
  #vpc_security_group_ids = [aws_security_group.rds.id]
  vpc_security_group_ids = [
    aws_security_group.rds.id,
    aws_security_group.eks_nodes.id,      
    "sg-07aa41c98a47155f1",               
  ]
  multi_az               = var.db_multi_az
  storage_encrypted      = true
  kms_key_id             = aws_kms_key.db.arn
  #kms_key_id          = var.kms_byok_arn

  # ----- 🔒 Backups / PITR -----
  # Enables automated backups (Point-In-Time Recovery)
  backup_retention_period = var.db_backup_retention
  # Choose a quiet UTC hour for your environment (example: 22:00–23:00 UTC)
  #preferred_backup_window = "22:00–23:00"

  # Keep tags on snapshots for tracking/chargeback
  copy_tags_to_snapshot = true

  # Final snapshot is skipped only if you later disable deletion_protection and delete
  skip_final_snapshot = true

  publicly_accessible             = false
  create_cloudwatch_log_group     = true
  enabled_cloudwatch_logs_exports = ["error", "general", "slowquery", "audit"]

  # Optional niceties (uncomment if you want them)
  # auto_minor_version_upgrade = true
  # performance_insights_enabled = true
  # performance_insights_kms_key_id = aws_kms_key.db.arn
  # performance_insights_retention_period = 7

  tags = local.tags
}
