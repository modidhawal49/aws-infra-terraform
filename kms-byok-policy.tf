############################################
# BYOK key policy (fixed service principals)
############################################

data "aws_region" "current" {}

# Resolve BYOK to key_id (UUID)
data "aws_kms_key" "byok" {
  key_id = var.kms_byok_arn
}

# Build the policy
data "aws_iam_policy_document" "byok_policy" {

  # 0) Root (break-glass)
  statement {
    sid = "AllowRootAccountAdministration"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }

  # 1) CloudWatch Logs for specific log groups (REGIONAL principal)
  statement {
    sid = "AllowCloudWatchLogsUseOfKeyForSpecificLogGroups"
    principals {
      type        = "Service"
      identifiers = ["logs.${data.aws_region.current.name}.amazonaws.com"]
    }
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values = [
        "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/eks/${var.name_prefix}-eks/cluster",
        "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:aws-waf-logs-${var.name_prefix}",
        "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/cloudtrail/${var.name_prefix}"
      ]
    }
  }

  # 1b) CW Logs create grants (REGIONAL principal)
  statement {
    sid = "AllowCloudWatchLogsCreateGrantForAWSResources"
    principals {
      type        = "Service"
      identifiers = ["logs.${data.aws_region.current.name}.amazonaws.com"]
    }
    actions = [
      "kms:CreateGrant",
      "kms:ListGrants",
      "kms:DescribeKey"
    ]
    resources = ["*"]
    condition {
      test     = "Bool"
      variable = "kms:GrantIsForAWSResource"
      values   = ["true"]
    }
  }

  # 2) CloudTrail (GLOBAL principal)
  statement {
    sid = "AllowCloudTrailUseOfTheKey"
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
    # Adjust trail name if different from "${var.name_prefix}-trail"
    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = ["arn:aws:cloudtrail:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:trail/${var.name_prefix}-trail"]
    }
    condition {
      test     = "StringEquals"
      variable = "kms:EncryptionContext:aws:cloudtrail:arn"
      values   = ["arn:aws:cloudtrail:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:trail/${var.name_prefix}-trail"]
    }
  }

  # 3) RDS (GLOBAL principal)
  statement {
    sid = "AllowRDSUseOfTheKeyForAWSResources"
    principals {
      type        = "Service"
      identifiers = ["rds.amazonaws.com"]
    }
    actions = [
      "kms:CreateGrant",
      "kms:DescribeKey",
      "kms:GenerateDataKey*",
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*"
    ]
    resources = ["*"]
    condition {
      test     = "Bool"
      variable = "kms:GrantIsForAWSResource"
      values   = ["true"]
    }
  }

  # 4) EFS (GLOBAL principal)
  statement {
    sid = "AllowEFSUseOfTheKeyForAWSResources"
    principals {
      type        = "Service"
      identifiers = ["elasticfilesystem.amazonaws.com"]
    }
    actions = [
      "kms:CreateGrant",
      "kms:DescribeKey",
      "kms:GenerateDataKey*",
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*"
    ]
    resources = ["*"]
    condition {
      test     = "Bool"
      variable = "kms:GrantIsForAWSResource"
      values   = ["true"]
    }
  }

  # 5) SNS (GLOBAL principal)
  statement {
    sid = "AllowSNSUserOfTheKeyForAWSResources"
    principals {
      type        = "Service"
      identifiers = ["sns.amazonaws.com"]
    }
    actions = [
      "kms:CreateGrant",
      "kms:DescribeKey",
      "kms:GenerateDataKey*",
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*"
    ]
    resources = ["*"]
    condition {
      test     = "Bool"
      variable = "kms:GrantIsForAWSResource"
      values   = ["true"]
    }
  }

  # 6) S3 (GLOBAL principal)
  statement {
    sid = "AllowS3UseOfTheKeyForAWSResources"
    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }
    actions = [
      "kms:CreateGrant",
      "kms:DescribeKey",
      "kms:GenerateDataKey*",
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*"
    ]
    resources = ["*"]
    condition {
      test     = "Bool"
      variable = "kms:GrantIsForAWSResource"
      values   = ["true"]
    }
  }

  # Allow ElastiCache service to use this BYOK (needed for at-rest encryption)
  statement {
    sid = "AllowElastiCacheUseOfTheKeyForAWSResources"
    principals {
      type        = "Service"
      identifiers = ["elasticache.amazonaws.com"]
    }
    actions = [
      "kms:CreateGrant",
      "kms:DescribeKey",
      "kms:GenerateDataKey*",
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
    ]
    resources = ["*"]
    condition {
      test     = "Bool"
      variable = "kms:GrantIsForAWSResource"
      values   = ["true"]
    }
  }

}

# Attach policy to BYOK
resource "aws_kms_key_policy" "byok" {
  key_id = data.aws_kms_key.byok.key_id
  policy = data.aws_iam_policy_document.byok_policy.json

  lifecycle {
    ignore_changes = [
      key_id,
      policy,  # optional, but recommended — avoids KMS policy churn
    ]
  }

}
