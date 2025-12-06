############################################
# Alerts (SNS)
############################################
resource "aws_sns_topic" "alerts" {
  name = "${var.name_prefix}-alerts"
  #kms_master_key_id = aws_kms_key.sns.arn
  kms_master_key_id = var.kms_byok_arn
  tags              = local.tags
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

############################################
# CloudTrail  -> S3 (/cloudtrail) + CloudWatch Logs
############################################

# Needed by AWS Config section below

# CloudTrail -> CloudWatch Logs
resource "aws_cloudwatch_log_group" "cloudtrail" {
  name              = "/aws/cloudtrail/${var.name_prefix}"
  retention_in_days = 30
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

#resource "aws_iam_role_policy" "ct_to_cw_attach" {
#  name   = "${var.name_prefix}-cloudtrail-to-cw"
#  role   = aws_iam_role.ct_to_cw.id
#  policy = data.aws_iam_policy_document.ct_to_cw_policy.json
#}

resource "aws_cloudtrail" "this" {
  name                          = "${var.name_prefix}-trail"
  s3_bucket_name                = aws_s3_bucket.logs.id
  s3_key_prefix                 = "cloudtrail"
  include_global_service_events = false
  is_multi_region_trail         = false
  enable_log_file_validation    = true

  # Encrypt CloudTrail log files with CMK (optional—uncomment when key is ready)
  # kms_key_id = aws_kms_key.cloudtrail.arn
  kms_key_id = var.kms_byok_arn

  # --- Management events (all read + write) ---
  advanced_event_selector {
    name = "ManagementEventsAll"
    field_selector {
      field  = "eventCategory"
      equals = ["Management"]
    }
    # No readOnly filter -> captures both read and write
  }

  # --- S3 object-level data events (all buckets, all regions) ---
  advanced_event_selector {
    name = "S3ObjectDataEventsAllBuckets"
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
      starts_with = ["arn:aws:s3:::"] # captures every bucket/object
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
      field       = "resources.ARN"
      starts_with = ["arn:aws:lambda:"]
    }
  }

  # --- DynamoDB table data events (all tables, all regions) ---
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

  # Also write to CloudWatch Logs (for KMS/API visibility in CW)
  cloud_watch_logs_group_arn = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
  cloud_watch_logs_role_arn  = aws_iam_role.ct_to_cw.arn

  # Ensure bucket policy + ownership controls exist first
  depends_on = [
    aws_s3_bucket_policy.logs,
    aws_s3_bucket_ownership_controls.logs,
    aws_iam_role_policy_attachment.ct_to_cw_managed,
    aws_kms_key_policy.byok
  ]

  tags = local.tags
}

############################################
# AWS Config  -> logs bucket /config
############################################

# Ensure the AWS Config service-linked role exists
resource "aws_iam_service_linked_role" "config" {
  aws_service_name = "config.amazonaws.com"
}

# Wait for the service-linked role to propagate
resource "time_sleep" "wait_slr_config" {
  depends_on      = [aws_iam_service_linked_role.config]
  create_duration = "240s"
}

# Configuration recorder using service-linked role
resource "aws_config_configuration_recorder" "this" {
  name     = "default"
  role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/config.amazonaws.com/AWSServiceRoleForConfig"

  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }

  depends_on = [
    aws_iam_service_linked_role.config,
    time_sleep.wait_slr_config
  ]
}

# Delivery channel (must wait until recorder exists)
resource "aws_config_delivery_channel" "this" {
  name           = "default"
  s3_bucket_name = aws_s3_bucket.logs.bucket
  s3_key_prefix  = "config"

  depends_on = [
    aws_config_configuration_recorder.this,
    aws_s3_bucket_policy.logs
  ]

  lifecycle {
    ignore_changes = all
  }

}

# Enable the recorder last
resource "aws_config_configuration_recorder_status" "this" {
  name       = aws_config_configuration_recorder.this.name
  is_enabled = true

  depends_on = [
    aws_config_delivery_channel.this,
    aws_config_configuration_recorder.this
  ]
}

############################################
# GuardDuty — Detector & Features
############################################

resource "aws_guardduty_detector" "this" {
  enable                       = var.enable_guardduty
  finding_publishing_frequency = var.guardduty_publishing_frequency # "FIFTEEN_MINUTES" | "ONE_HOUR" | "SIX_HOURS"
  tags                         = local.tags
}

# EKS audit logs (EKS Protection)
resource "aws_guardduty_detector_feature" "eks_audit" {
  detector_id = aws_guardduty_detector.this.id
  name        = "EKS_AUDIT_LOGS"
  status      = "ENABLED"
}

# EKS runtime protection (agent add-on managed by GuardDuty)
resource "aws_guardduty_detector_feature" "eks_runtime" {
  detector_id = aws_guardduty_detector.this.id
  name        = "EKS_RUNTIME_MONITORING"
  status      = "ENABLED"

  additional_configuration {
    name   = "EKS_ADDON_MANAGEMENT"
    status = "ENABLED"
  }
}

# RDS login event protection
resource "aws_guardduty_detector_feature" "rds_login" {
  detector_id = aws_guardduty_detector.this.id
  name        = "RDS_LOGIN_EVENTS"
  status      = "ENABLED"
}

# S3 data events protection (leverages CloudTrail data events)
resource "aws_guardduty_detector_feature" "s3_data" {
  detector_id = aws_guardduty_detector.this.id
  name        = "S3_DATA_EVENTS"
  status      = "ENABLED"
}

# Optional: EC2 EBS malware protection
# resource "aws_guardduty_detector_feature" "ebs_malware" {
#   detector_id = aws_guardduty_detector.this.id
#   name        = "EBS_MALWARE_PROTECTION"
#   status      = "ENABLED"
# }

############################################
# AWS Backup (simple daily)
############################################
data "aws_iam_policy_document" "backup_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["backup.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "backup" {
  name               = "${var.name_prefix}-backup-role"
  assume_role_policy = data.aws_iam_policy_document.backup_assume.json
}

resource "aws_iam_role_policy_attachment" "backup_attach" {
  role       = aws_iam_role.backup.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

resource "aws_backup_vault" "this" {
  name = "${var.name_prefix}-vault"
}

resource "aws_backup_plan" "daily" {
  name = "${var.name_prefix}-daily"

  rule {
    rule_name         = "daily"
    target_vault_name = aws_backup_vault.this.name
    schedule          = "cron(0 18 * * ? *)" # 18:00 UTC daily

    lifecycle {
      delete_after = 7
    }
  }
}

resource "aws_backup_selection" "rds" {
  iam_role_arn = aws_iam_role.backup.arn
  name         = "rds"
  plan_id      = aws_backup_plan.daily.id
  resources    = [module.db.db_instance_arn]

lifecycle {
  ignore_changes = [
    resources,
    not_resources,
    condition,
  ]
}
}

resource "aws_backup_selection" "efs" {
  iam_role_arn = aws_iam_role.backup.arn
  name         = "efs"
  plan_id      = aws_backup_plan.daily.id
  resources    = [aws_efs_file_system.this.arn]
}

# New managed policy (create)
resource "aws_iam_policy" "ct_to_cw" {
  name        = "${var.name_prefix}-cloudtrail-to-cw"
  description = "Allow CloudTrail to publish to CloudWatch Logs for ${var.name_prefix}"
  policy      = data.aws_iam_policy_document.ct_to_cw_policy.json
  tags        = local.tags
}

# New attachment (link it to the same role)
resource "aws_iam_role_policy_attachment" "ct_to_cw_managed" {
  role       = aws_iam_role.ct_to_cw.name # same role the inline uses
  policy_arn = aws_iam_policy.ct_to_cw.arn
}
