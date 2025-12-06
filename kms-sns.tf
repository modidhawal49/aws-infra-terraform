##############################################
# KMS Key for SNS Topic (ewec-nonprod-alerts)
##############################################

data "aws_iam_policy_document" "sns_kms_policy" {
  statement {
    sid    = "EnableIamRootPermissions"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::035838344560:root"]
    }

    actions   = ["kms:*"]
    resources = ["*"]
  }

  statement {
    sid    = "AllowSNSToUseKeyForThisTopic"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["sns.amazonaws.com"]
    }

    actions   = ["kms:Decrypt", "kms:GenerateDataKey*"]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = ["035838344560"]
    }

    condition {
      test     = "ArnLike"
      variable = "kms:EncryptionContext:aws:sns:arn"
      values   = ["arn:aws:sns:me-central-1:035838344560:ewec-nonprod-alerts"]
    }
  }
}

resource "aws_kms_key" "sns" {
  description         = "KMS key for SNS topic ewec-nonprod-alerts (nonprod)"
  enable_key_rotation = true
  policy              = data.aws_iam_policy_document.sns_kms_policy.json
  tags                = local.tags
}

resource "aws_kms_alias" "sns" {
  name          = "alias/sns/ewec-nonprod-alerts"
  target_key_id = aws_kms_key.sns.key_id
}
