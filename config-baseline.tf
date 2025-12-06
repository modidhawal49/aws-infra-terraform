############################################
# config-baseline.tf
# AWS Config baseline managed rules (no EventBridge)
############################################

########################################################
# AWS Config Managed Rules (valid identifiers, no duplicates)
########################################################

# CloudTrail must be enabled in the account
resource "aws_config_config_rule" "cloudtrail_enabled" {
  name = "CLOUD_TRAIL_ENABLED"

  source {
    owner             = "AWS"
    source_identifier = "CLOUD_TRAIL_ENABLED"
  }
}

# CloudTrail log file validation should be enabled
resource "aws_config_config_rule" "cloudtrail_log_validation" {
  name = "CLOUD_TRAIL_LOG_FILE_VALIDATION_ENABLED"

  source {
    owner             = "AWS"
    source_identifier = "CLOUD_TRAIL_LOG_FILE_VALIDATION_ENABLED"
  }
}

# Strong IAM password policy
resource "aws_config_config_rule" "iam_password_policy" {
  name = "IAM_PASSWORD_POLICY"

  source {
    owner             = "AWS"
    source_identifier = "IAM_PASSWORD_POLICY"
  }
}

# S3 buckets must use server-side encryption
resource "aws_config_config_rule" "s3_sse" {
  name = "S3_BUCKET_SERVER_SIDE_ENCRYPTION_ENABLED"

  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_SERVER_SIDE_ENCRYPTION_ENABLED"
  }
}

# S3 public access prohibited (read)
resource "aws_config_config_rule" "s3_public_read" {
  name = "S3_BUCKET_PUBLIC_READ_PROHIBITED"

  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_PUBLIC_READ_PROHIBITED"
  }
}

# S3 public access prohibited (write)
resource "aws_config_config_rule" "s3_public_write" {
  name = "S3_BUCKET_PUBLIC_WRITE_PROHIBITED"

  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_PUBLIC_WRITE_PROHIBITED"
  }
}

# Security group should not allow unrestricted SSH (corrected identifier)
resource "aws_config_config_rule" "restricted_ssh" {
  name = "INCOMING_SSH_DISABLED"

  source {
    owner             = "AWS"
    source_identifier = "INCOMING_SSH_DISABLED"
  }
}

# EBS encryption by default should be enabled (valid identifier)
resource "aws_config_config_rule" "ebs_encryption_default" {
  name = "EC2_EBS_ENCRYPTION_BY_DEFAULT"

  source {
    owner             = "AWS"
    source_identifier = "EC2_EBS_ENCRYPTION_BY_DEFAULT"
  }
}

# RDS snapshots must not be public
resource "aws_config_config_rule" "rds_snapshots_public" {
  name = "RDS_SNAPSHOTS_PUBLIC_PROHIBITED"

  source {
    owner             = "AWS"
    source_identifier = "RDS_SNAPSHOTS_PUBLIC_PROHIBITED"
  }
}

# NOTE:
# You already have RDS_STORAGE_ENCRYPTED defined elsewhere.
# Do NOT redefine that rule here to avoid duplicate resource errors.

