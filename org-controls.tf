############################################
# Alerts (SNS)
############################################
resource "aws_sns_topic" "alerts" {
  name = "${var.name_prefix}-alerts"
  #kms_master_key_id = aws_kms_key.sns.arn
  kms_master_key_id = var.kms_byok_arn
  tags = local.tags
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

############################################
# CloudTrail -> S3 (/cloudtrail) + CloudWatch Logs
############################################
# CloudTrail -> CloudWatch Logs
resource "aws_cloudwatch_log_group" "cloudtrail" {
  name              = "/aws/cloudtrail/${var.name_prefix}"
  retention_in_days = 365
  kms_key_id        = var.kms_byok_arn
  tags              = local.tags
}

data "aws_iam_policy_document" "ct_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ct_to_cw" {
  name               = "${var.name_prefix}-cloudtrail-to-cw"
  assume_role_policy = data.aws_iam_policy_document.ct_assume.json
  tags               = local.tags
}

data "aws_iam_policy_document" "ct_to_cw_policy" {
  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams"
    ]
    resources = ["${aws_cloudwatch_log_group.cloudtrail.arn}:*"]
  }
}

resource "aws_iam_role_policy" "ct_to_cw_attach" {
  name   = "${var.name_prefix}-cloudtrail-to-cw"
  role   = aws_iam_role.ct_to_cw.id
  policy = data.aws_iam_policy_document.ct_to_cw_policy.json
}

resource "aws_cloudtrail" "this" {
  name                          = "${var.name_prefix}-trail"
  s3_bucket_name                = aws_s3_bucket.logs.id
  s3_key_prefix                 = "cloudtrail"
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true

  # NEW: Encrypt CloudTrail log files with CMK
  #kms_key_id                    = aws_kms_key.cloudtrail.arn
  kms_key_id = var.kms_byok_arn

  # --- Management events (all read/write) ---
  advanced_event_selector {
    name = "ManagementEventsAll"
    field_selector {
      field  = "eventCategory"
      equals = ["Management"]
    }
  }

  # --- S3 object-level data events for ALL buckets ---
  advanced_event_selector {
    name = "S3DataEventsAllBuckets"
    field_selector {
      field  = "eventCategory"
      equals = ["Data"]
    }
    field_selector {
      field  = "resources.type"
      equals = ["AWS::S3::Object"]
    }
    field_selector {
      field       = "resources.ARN"
      starts_with = ["arn:aws:s3:::"]
    }
  }

# --- Lambda function invoke data events (all functions, all regions) ---
advanced_event_selector {
  name = "LambdaDataEventsAllFunctions"

  field_selector {
    field  = "eventCategory"
    equals = ["Data"]
  }
  field_selector {
    field  = "resources.type"
    equals = ["AWS::Lambda::Function"]
  }
  field_selector {
    field        = "resources.ARN"
    starts_with  = ["arn:aws:lambda:"]
  }
}

# --- DynamoDB table-level data events (all tables) ---
advanced_event_selector {
  name = "DynamoDBDataEventsAllTables"

  field_selector {
    field  = "eventCategory"
    equals = ["Data"]
  }
  field_selector {
    field  = "resources.type"
    equals = ["AWS::DynamoDB::Table"]
  }
  field_selector {
    field       = "resources.ARN"
    starts_with = ["arn:aws:dynamodb:"]
  }
}


  # Insights
  insight_selector { insight_type = "ApiCallRateInsight" }
  insight_selector { insight_type = "ApiErrorRateInsight" }

  # Send to CloudWatch Logs (set to 365d retention above)
  cloud_watch_logs_group_arn = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
  cloud_watch_logs_role_arn  = aws_iam_role.ct_to_cw.arn

  depends_on = [
    aws_s3_bucket_policy.logs,
    aws_s3_bucket_ownership_controls.logs,
    aws_iam_role_policy.ct_to_cw_attach,
    aws_kms_key_policy.byok
  ]

  tags = local.tags
}


############################################
# AWS Config -> logs bucket /config (no SLR creation)
############################################
resource "aws_config_configuration_recorder" "this" {
  name     = "default"
  role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/config.amazonaws.com/AWSServiceRoleForConfig"

  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }
}

resource "aws_config_delivery_channel" "this" {
  name           = "default"
  s3_bucket_name = aws_s3_bucket.logs.bucket
  s3_key_prefix  = "config"

  depends_on = [
    aws_config_configuration_recorder.this,
    aws_s3_bucket_policy.logs
  ]
}

resource "aws_config_configuration_recorder_status" "this" {
  name       = aws_config_configuration_recorder.this.name
  is_enabled = true

  depends_on = [
    aws_config_delivery_channel.this,
    aws_config_configuration_recorder.this
  ]
}

############################################
# AWS Backup – Vault + Plans + Selections
# Matches diagram:
# - RDS daily backups, retain 7d (PITR via RDS automated backups)
# - EFS hourly (7d) + daily (15d)
# - S3 continuous backup (PITR, 35d retention)
############################################

# Assume-role policy for AWS Backup
data "aws_iam_policy_document" "backup_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["backup.amazonaws.com"]
    }
  }
}

# IAM role used by Backup selections
resource "aws_iam_role" "backup" {
  name               = "${var.name_prefix}-backup-role"
  assume_role_policy = data.aws_iam_policy_document.backup_assume.json
  tags               = local.tags
}

# Generic backup permissions
resource "aws_iam_role_policy_attachment" "backup_attach_generic" {
  role       = aws_iam_role.backup.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

# Buckets protected by AWS Backup for S3 (add more as needed)
locals {
  s3_backup_bucket_arns = [
    aws_s3_bucket.logs.arn,
    # add app/media buckets here as you create them, e.g.:
    # aws_s3_bucket.static.arn,
  ]
  s3_backup_object_arns = [for b in local.s3_backup_bucket_arns : "${b}/*"]
}

# Inline policy with just-enough S3 permissions for backups
data "aws_iam_policy_document" "backup_s3_inline" {
  # Bucket-level permissions
  statement {
    sid     = "S3BucketLevelForBackup"
    effect  = "Allow"
    actions = [
      "s3:GetBucketLocation",
      "s3:GetBucketTagging",
      "s3:GetBucketVersioning",
      "s3:ListBucket",
      "s3:ListBucketVersions",
      "s3:ListBucketMultipartUploads"
    ]
    resources = local.s3_backup_bucket_arns
  }

  # Object-level permissions
  statement {
    sid     = "S3ObjectLevelForBackup"
    effect  = "Allow"
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:GetObjectTagging",
      "s3:GetObjectVersionTagging",
      "s3:GetObjectAcl",
      "s3:GetObjectVersionAcl",
      "s3:ListMultipartUploadParts"
    ]
    resources = local.s3_backup_object_arns
  }
}

# Attach the inline policy to the AWS Backup role
resource "aws_iam_role_policy" "backup_s3_inline" {
  name   = "${var.name_prefix}-backup-s3-inline"
  role   = aws_iam_role.backup.id
  policy = data.aws_iam_policy_document.backup_s3_inline.json
}


# KMS key for the backup vault
resource "aws_kms_key" "backup" {
  description             = "KMS key for AWS Backup Vault"
  enable_key_rotation     = true
  deletion_window_in_days = 7
  tags                    = local.tags

  lifecycle {
    ignore_changes = [
      description,
      tags,
      tags_all,
    ]
  }

}

resource "aws_kms_alias" "backup" {
  name          = "alias/${var.name_prefix}-backup"
  target_key_id = aws_kms_key.backup.key_id
}

# Encrypted backup vault
resource "aws_backup_vault" "this" {
  name        = "${var.name_prefix}-vault"
  kms_key_arn = aws_kms_key.backup.arn
  tags        = local.tags
}

######## RDS: Daily 7d (PITR via RDS automated backups) ########
resource "aws_backup_plan" "rds" {
  name = "${var.name_prefix}-backup-plan-rds"

  rule {
    rule_name         = "rds-daily-7d"
    target_vault_name = aws_backup_vault.this.name
    schedule          = "cron(0 01 * * ? *)" # 01:00 UTC daily
    start_window      = 60
    completion_window = 480

    lifecycle {
      delete_after = 35
      opt_in_to_archive_for_supported_resources = false
      cold_storage_after                        = 0
    }
  }

  tags = local.tags
}

resource "aws_backup_selection" "rds" {
  name         = "rds-selection"
  iam_role_arn = aws_iam_role.backup.arn
  plan_id      = aws_backup_plan.rds.id

  resources = [
    module.db.db_instance_arn
    # For Aurora, switch to cluster ARN output:
    # module.db.rds_cluster_arn
  ]
}

######## EFS: Hourly 7d + Daily 15d ########
resource "aws_backup_plan" "efs" {
  name = "${var.name_prefix}-backup-plan-efs"

  # Hourly backups, retain 7 days
  rule {
    rule_name         = "efs-hourly-7d"
    target_vault_name = aws_backup_vault.this.name
    schedule          = "cron(0 * * * ? *)"  # every hour at :00
    start_window      = 60
    completion_window = 480

    lifecycle {
      delete_after = 7
    }
  }

  # Daily backups, retain 15 days
  rule {
    rule_name         = "efs-daily-15d"
    target_vault_name = aws_backup_vault.this.name
    schedule          = "cron(0 02 * * ? *)" # 02:00 UTC daily
    start_window      = 60
    completion_window = 480

    lifecycle {
      delete_after = 15
    }
  }

  tags = local.tags
}

resource "aws_backup_selection" "efs" {
  name         = "efs-selection"
  iam_role_arn = aws_iam_role.backup.arn
  plan_id      = aws_backup_plan.efs.id

  resources = [
    aws_efs_file_system.this.arn
  ]
}

######## S3: Continuous backup (PITR) ########
resource "aws_backup_plan" "s3" {
  name = "${var.name_prefix}-backup-plan-s3"

  rule {
    rule_name                = "s3-continuous"
    target_vault_name        = aws_backup_vault.this.name
    enable_continuous_backup = true

    # Retain PITR window (max 35 days currently)
    lifecycle {
      delete_after = 35
    }
  }

  tags = local.tags

  lifecycle {
    ignore_changes = [
      rule,
    ]
  }

}

resource "aws_backup_selection" "s3" {
  name         = "s3-selection"
  iam_role_arn = aws_iam_role.backup.arn
  plan_id      = aws_backup_plan.s3.id

  resources = [
    aws_s3_bucket.logs.arn
    # Add other app/media buckets here as you create them
  ]
}

# OPTIONAL: Vault Lock (immutability) – uncomment if required
# resource "aws_backup_vault_lock_configuration" "this" {
#   backup_vault_name  = aws_backup_vault.this.name
#   min_retention_days = 7
#   max_retention_days = 3650
#   changeable_for_days = 3
# }

