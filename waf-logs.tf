############################################
# NONPROD: WAF → CloudWatch Logs
############################################

# 1) Log group for WAF logs
resource "aws_cloudwatch_log_group" "waf_prod" {
  name              = "aws-waf-logs-ewec-prod"
  retention_in_days = 90
  #kms_key_id        = aws_kms_key.logs.arn
  kms_key_id        = var.kms_byok_arn
  tags              = local.tags
}

# 2) Explicit CW Logs resource policy for waf.amazonaws.com (defensive)
data "aws_iam_policy_document" "waf_logs_resource_policy_prod" {
  statement {
    sid     = "AllowWAFToWriteLogs"
    effect  = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams"
    ]
    principals {
      type        = "Service"
      identifiers = ["waf.amazonaws.com"]
    }
    resources = ["${aws_cloudwatch_log_group.waf_prod.arn}:*"]
  }
}

resource "aws_cloudwatch_log_resource_policy" "waf_prod" {
  policy_name     = "AWSWAF-LOGS-Explicit-Nonprod"
  policy_document = data.aws_iam_policy_document.waf_logs_resource_policy_prod.json
}

# 3) Attach WAF logging to the prod WebACL (REGIONAL)
#    If your WebACL is a TF resource, reference it directly instead of data source.
data "aws_wafv2_web_acl" "prod" {
  name  = "ewec-prod-waf"   # <-- change if your WebACL name differs
  scope = "REGIONAL"
}

resource "aws_wafv2_web_acl_logging_configuration" "prod" {
  resource_arn           = data.aws_wafv2_web_acl.prod.arn
  log_destination_configs = [aws_cloudwatch_log_group.waf_prod.arn]
}
