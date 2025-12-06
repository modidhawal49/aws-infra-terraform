############################################
# VPC Flow Logs → S3
############################################

# VPC Flow Logs resource
resource "aws_flow_log" "vpc" {
  vpc_id               = module.vpc.vpc_id
  log_destination      = aws_s3_bucket.logs.arn
  log_destination_type = "s3"
  traffic_type         = var.flowlog_traffic_type

  # 1-minute granularity (default 600 seconds = 10 minutes)
  max_aggregation_interval = 60

  tags = merge(local.tags, {
    Name = "${var.name_prefix}-vpc-flowlogs"
  })
}

# Update bucket policy so Flow Logs can deliver to S3
#resource "aws_s3_bucket_policy" "logs_flowlogs" {
#  bucket = aws_s3_bucket.logs.id

#  policy = jsonencode({
#    Version = "2012-10-17",
#    Statement = [
#      {
#        Sid: "AllowVPCFlowLogsDelivery",
#        Effect: "Allow",
#        Principal = { Service = "delivery.logs.amazonaws.com" },
#        Action = "s3:PutObject",
#        Resource = "${aws_s3_bucket.logs.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*",
#        Condition = {
#          StringEquals = {
#            "s3:x-amz-acl"   = "bucket-owner-full-control",
#            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
#          }
#        }
#      }
#    ]
#  })
#}

# Replace existing aws_s3_bucket_policy.logs_flowlogs with this full policy
resource "aws_s3_bucket_policy" "logs_flowlogs" {
  bucket = aws_s3_bucket.logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Deny insecure (non-TLS) requests
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource  = [
          aws_s3_bucket.logs.arn,
          "${aws_s3_bucket.logs.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      },

      # VPC Flow Logs delivery (AWSLogs prefix)
      {
        Sid = "AllowVPCFlowLogsDelivery"
        Effect = "Allow"
        Principal = { Service = "delivery.logs.amazonaws.com" }
        Action = "s3:PutObject"
        Resource = "${aws_s3_bucket.logs.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
            "s3:x-amz-acl"      = "bucket-owner-full-control"
          }
        }
      },

      # ALB access logs
      {
        Sid = "AllowALBLogsPut"
        Effect = "Allow"
        Principal = { Service = "logdelivery.elasticloadbalancing.amazonaws.com" }
        Action = "s3:PutObject"
        Resource = "${aws_s3_bucket.logs.arn}/alb/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      },
      {
        Sid = "AllowALBLogsGetBucketAcl"
        Effect = "Allow"
        Principal = { Service = "logdelivery.elasticloadbalancing.amazonaws.com" }
        Action = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.logs.arn
      },

      # CloudTrail
      {
        Sid = "CloudTrailWrite"
        Effect = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action = "s3:PutObject"
        Resource = "${aws_s3_bucket.logs.arn}/cloudtrail/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
            "s3:x-amz-acl"      = "bucket-owner-full-control"
          }
        }
      },
      {
        Sid = "CloudTrailGetBucketAcl"
        Effect = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.logs.arn
      },

      # AWS Config
      {
        Sid = "ConfigWrite"
        Effect = "Allow"
        Principal = { Service = "config.amazonaws.com" }
        Action = "s3:PutObject"
        Resource = "${aws_s3_bucket.logs.arn}/config/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      },
      {
        Sid = "ConfigGetBucketAcl"
        Effect = "Allow"
        Principal = { Service = "config.amazonaws.com" }
        Action = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.logs.arn
      }
    ]
  })
}


############################################
# VPC Flow Logs → CloudWatch Logs (365d)
############################################

# Log group for VPC Flow Logs
resource "aws_cloudwatch_log_group" "vpc_flow" {
  name              = "/aws/vpcflow/${var.name_prefix}"
  retention_in_days = 365
  tags              = local.tags
}

# IAM role to publish VPC Flow Logs to CWL
data "aws_iam_policy_document" "vpc_flow_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "vpc_flow_to_cw" {
  name               = "${var.name_prefix}-vpc-flow-to-cw"
  assume_role_policy = data.aws_iam_policy_document.vpc_flow_assume.json
  tags               = local.tags
}

data "aws_iam_policy_document" "vpc_flow_cw_policy" {
  statement {
    actions   = ["logs:CreateLogStream","logs:PutLogEvents","logs:DescribeLogGroups","logs:DescribeLogStreams"]
    resources = ["${aws_cloudwatch_log_group.vpc_flow.arn}:*"]
  }
}

resource "aws_iam_role_policy" "vpc_flow_to_cw_attach" {
  name   = "${var.name_prefix}-vpc-flow-to-cw"
  role   = aws_iam_role.vpc_flow_to_cw.id
  policy = data.aws_iam_policy_document.vpc_flow_cw_policy.json
}

# Additional Flow Log publisher to CWL (keep your S3 flow log as-is)
resource "aws_flow_log" "vpc_to_cwl" {
  vpc_id               = module.vpc.vpc_id
  log_destination_type = "cloud-watch-logs"
  log_destination      = aws_cloudwatch_log_group.vpc_flow.arn
  iam_role_arn         = aws_iam_role.vpc_flow_to_cw.arn
  traffic_type         = var.flowlog_traffic_type
  max_aggregation_interval = 60
  tags = merge(local.tags, { Name = "${var.name_prefix}-vpc-flow-cwl" })
}
