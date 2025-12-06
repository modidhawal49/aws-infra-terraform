resource "aws_kms_key" "eks_secrets" {
  description             = "KMS key for EKS secrets envelope encryption"
  deletion_window_in_days = 10
  enable_key_rotation     = true
  policy = data.aws_iam_policy_document.eks_kms_policy.json

  lifecycle {
    ignore_changes = all
  }

}

data "aws_iam_policy_document" "eks_kms_policy" {
  statement {
    sid    = "Allow EKS cluster to use this key"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }

    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]

    resources = ["*"]
  }
}

resource "aws_kms_alias" "eks_secrets" {
  name          = "alias/ewec-prod-eks-secrets"
  target_key_id = aws_kms_key.eks_secrets.key_id

  lifecycle {
    ignore_changes = all
  }

}
