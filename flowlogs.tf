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
resource "aws_s3_bucket_policy" "logs_flowlogs" {
  bucket = aws_s3_bucket.logs.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid : "AllowVPCFlowLogsDelivery",
        Effect : "Allow",
        Principal = { Service = "delivery.logs.amazonaws.com" },
        Action    = "s3:PutObject",
        Resource  = "${aws_s3_bucket.logs.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*",
        Condition = {
          StringEquals = {
            "s3:x-amz-acl"      = "bucket-owner-full-control",
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })

  lifecycle {
    ignore_changes = [
      policy
    ]
  }

}
