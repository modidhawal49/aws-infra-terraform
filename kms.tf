resource "aws_kms_key" "db" {
  description             = "KMS for RDS"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  tags                    = local.tags

  lifecycle {
    ignore_changes = [
      description,
      enable_key_rotation,
      deletion_window_in_days,
      tags,
      tags_all,
    ]
  }

}
resource "aws_kms_key" "efs" {
  description             = "KMS for EFS"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  tags                    = local.tags

  lifecycle {
    ignore_changes = [
      description,
      enable_key_rotation,
      deletion_window_in_days,
      tags,
      tags_all,
    ]
  }

}


resource "aws_kms_key" "logs" {
  description             = "KMS for CloudWatch Logs (workloads)"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  tags                    = local.tags

  lifecycle {
    ignore_changes = [
      description,
      enable_key_rotation,
      deletion_window_in_days,
      tags,
      tags_all,
    ]
  }

}

resource "aws_kms_alias" "logs" {
  name          = "alias/${var.name_prefix}/cloudwatch-logs"
  target_key_id = aws_kms_key.logs.key_id

  lifecycle {
    ignore_changes = [
      target_key_id,
    ]
  }

}


############################################
# NONPROD: Extend existing KMS key for WAF CloudWatch Logs
# Detected logs key: aws_kms_key.logs
############################################

data "aws_region" "nonprod_waf" {}
data "aws_caller_identity" "nonprod_waf" {}

data "aws_iam_policy_document" "logs_kms_policy_nonprod" {
  # Safe admin access to avoid lockout
  statement {
    sid     = "AllowAccountRootFullAccess"
    effect  = "Allow"
    actions = ["kms:*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.nonprod_waf.account_id}:root"]
    }
    resources = ["*"]
  }

  # Allow CloudWatch Logs to use the key for the EKS workloads + WAF log groups
  statement {
    sid    = "AllowCWLogsEncryptDecrypt"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["logs.${data.aws_region.nonprod_waf.name}.amazonaws.com"]
    }
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]
    condition {
      test     = "ArnEquals"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values = [
        "arn:aws:logs:${data.aws_region.nonprod_waf.name}:${data.aws_caller_identity.nonprod_waf.account_id}:log-group:/aws/eks/ewec-nonprod-eks/workloads",
        "arn:aws:logs:${data.aws_region.nonprod_waf.name}:${data.aws_caller_identity.nonprod_waf.account_id}:log-group:aws-waf-logs-ewec-nonprod"
      ]
    }
    resources = ["*"]
  }

  # Allow CW Logs to create grants
  statement {
    sid    = "AllowCWLogsCreateGrant"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["logs.${data.aws_region.nonprod_waf.name}.amazonaws.com"]
    }
    actions = ["kms:CreateGrant"]
    condition {
      test     = "Bool"
      variable = "kms:GrantIsForAWSResource"
      values   = ["true"]
    }
    resources = ["*"]
  }
}

# Attach/merge policy to EXISTING key
resource "aws_kms_key_policy" "logs_nonprod" {
  key_id = aws_kms_key.logs.key_id
  policy = data.aws_iam_policy_document.logs_kms_policy_nonprod.json

  lifecycle {
    ignore_changes = [ policy, bypass_policy_lockout_safety_check ]
  }

}
