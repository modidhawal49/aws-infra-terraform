############################################
# IRSA for aws-for-fluent-bit → CloudWatch Logs
############################################

locals {
  fluentbit_sa_name      = "fluent-bit"
  fluentbit_sa_namespace = "kube-system"
}

# Trust policy: allow k8s SA to assume the role via EKS OIDC
data "aws_iam_policy_document" "fluentbit_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${module.eks.oidc_provider}:sub"
      values   = ["system:serviceaccount:${local.fluentbit_sa_namespace}:${local.fluentbit_sa_name}"]
    }
    condition {
      test     = "StringEquals"
      variable = "${module.eks.oidc_provider}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "fluentbit" {
  name               = "${var.name_prefix}-fluent-bit"
  assume_role_policy = data.aws_iam_policy_document.fluentbit_trust.json
  tags               = local.tags
}

# Minimal CW Logs perms scoped to the Terraform-managed log group
data "aws_iam_policy_document" "fluentbit_cw_doc" {
  statement {
    sid = "CWLogsWrite"
    actions = [
      "logs:CreateLogStream",
      "logs:DescribeLogStreams",
      "logs:PutLogEvents"
    ]
    resources = ["${aws_cloudwatch_log_group.eks_workloads.arn}:*"]
  }
}

# NEW policy with a NEW AWS name (no conflict with the old one)
resource "aws_iam_policy" "fluentbit_cw_new" {
  name        = "${var.name_prefix}-fluentbit-cw" # NEW policy in AWS
  description = "Allow aws-for-fluent-bit to write to workload log group"
  policy      = data.aws_iam_policy_document.fluentbit_cw_doc.json
  tags        = local.tags
}

# Attach the NEW policy (old policy remains attached too — no deletes)
resource "aws_iam_role_policy_attachment" "fluentbit_cw_new_attach" {
  role       = aws_iam_role.fluentbit.name
  policy_arn = aws_iam_policy.fluentbit_cw_new.arn
}

