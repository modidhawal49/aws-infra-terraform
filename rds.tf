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
  apply_immediately     = true
  deletion_protection   = true

  create_db_instance = false

  db_name  = var.db_name
  username = var.db_user
  #password = var.db_pass
  manage_master_user_password   = true
  master_user_secret_kms_key_id = var.kms_byok_arn

  db_subnet_group_name   = module.vpc.database_subnet_group
  vpc_security_group_ids = [
    aws_security_group.rds.id,
    aws_security_group.eks_nodes.id
  ]
  multi_az               = var.db_multi_az
  storage_encrypted      = true
  kms_key_id             = aws_kms_key.db.arn
  #kms_key_id          = var.kms_byok_arn
  skip_final_snapshot = true

  publicly_accessible             = false
  create_cloudwatch_log_group     = true
  enabled_cloudwatch_logs_exports = ["error", "general", "slowquery", "audit"]
  tags                            = local.tags

}
