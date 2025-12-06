############################################
# Logs Bucket
############################################
resource "aws_s3_bucket" "logs" {
  bucket        = "${var.name_prefix}-logs"
  force_destroy = true
  tags          = merge(local.tags, { Name = "${var.name_prefix}-logs" })

  lifecycle {
    ignore_changes = [
      force_destroy,
      tags,
    ]
  }

}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    apply_server_side_encryption_by_default {
      #sse_algorithm = "AES256"
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_byok_arn
    }
  }
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket                  = aws_s3_bucket.logs.id
  block_public_acls       = true
  block_public_policy     = true
  restrict_public_buckets = true
  ignore_public_acls      = true
}

# ✅ Allow ACLs so services can set bucket-owner-full-control
resource "aws_s3_bucket_ownership_controls" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# Keep bucket ACL explicit = private
resource "aws_s3_bucket_acl" "logs" {
  bucket     = aws_s3_bucket.logs.id
  acl        = "private"
  depends_on = [aws_s3_bucket_ownership_controls.logs]

  lifecycle {
    ignore_changes = [
      acl,
      access_control_policy,
    ]
  }

}

# --------------------------------------------------------------------

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket_policy" "logs" {
  bucket = aws_s3_bucket.logs.id
  depends_on = [
    aws_s3_bucket_ownership_controls.logs,
    aws_s3_bucket_acl.logs
  ]

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [

      {
        "Sid" : "DenyInsecureTransport",
        "Effect" : "Deny",
        "Principal" : "*",
        "Action" : "s3:*",
        "Resource" : [
          "${aws_s3_bucket.logs.arn}",
          "${aws_s3_bucket.logs.arn}/*"
        ],
        "Condition" : {
          "Bool" : { "aws:SecureTransport" : "false" }
        }
      },

      # ✅ ALB access logs
      {
        "Sid" : "AllowALBLogsPut",
        "Effect" : "Allow",
        "Principal" : { "Service" : "logdelivery.elasticloadbalancing.amazonaws.com" },
        "Action" : "s3:PutObject",
        "Resource" : "${aws_s3_bucket.logs.arn}/${var.alb_logs_prefix}/AWSLogs/${data.aws_caller_identity.current.account_id}/*",
        "Condition" : {
          "StringEquals" : { "s3:x-amz-acl" : "bucket-owner-full-control" }
        }
      },
      {
        "Sid" : "AllowALBLogsGetBucketAcl",
        "Effect" : "Allow",
        "Principal" : { "Service" : "logdelivery.elasticloadbalancing.amazonaws.com" },
        "Action" : "s3:GetBucketAcl",
        "Resource" : "${aws_s3_bucket.logs.arn}"
      },

      # ✅ VPC Flow Logs
      {
        "Sid" : "AllowVPCFlowLogsPut",
        "Effect" : "Allow",
        "Principal" : { "Service" : "delivery.logs.amazonaws.com" },
        "Action" : "s3:PutObject",
        "Resource" : "${aws_s3_bucket.logs.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*",
        "Condition" : {
          "StringEquals" : {
            "s3:x-amz-acl" : "bucket-owner-full-control",
            "aws:SourceAccount" : "${data.aws_caller_identity.current.account_id}"
          }
        }
      },

      # ✅ CloudTrail
      {
        "Sid" : "CloudTrailGetBucketAcl",
        "Effect" : "Allow",
        "Principal" : { "Service" : "cloudtrail.amazonaws.com" },
        "Action" : "s3:GetBucketAcl",
        "Resource" : "${aws_s3_bucket.logs.arn}",
        "Condition" : {
          "StringEquals" : {
            "aws:SourceArn" : "arn:aws:cloudtrail:me-central-1:${data.aws_caller_identity.current.account_id}:trail/ewec-nonprod-trail"
          }
        }
      },
      {
        "Sid" : "CloudTrailWrite",
        "Effect" : "Allow",
        "Principal" : { "Service" : "cloudtrail.amazonaws.com" },
        "Action" : "s3:PutObject",
        "Resource" : "${aws_s3_bucket.logs.arn}/cloudtrail/AWSLogs/${data.aws_caller_identity.current.account_id}/*",
        "Condition" : {
          "StringEquals" : {
            "s3:x-amz-acl" : "bucket-owner-full-control",
            "aws:SourceArn" : "arn:aws:cloudtrail:me-central-1:${data.aws_caller_identity.current.account_id}:trail/ewec-nonprod-trail",
            "s3:x-amz-server-side-encryption" : "aws:kms",
            "s3:x-amz-server-side-encryption-aws-kms-key-id" : "${var.kms_byok_arn}",
            "aws:SourceAccount" : "${data.aws_caller_identity.current.account_id}"
          }
        }
      },

      # ✅ AWS Config
      {
        "Sid" : "ConfigGetBucketAcl",
        "Effect" : "Allow",
        "Principal" : { "Service" : "config.amazonaws.com" },
        "Action" : "s3:GetBucketAcl",
        "Resource" : "${aws_s3_bucket.logs.arn}"
      },
      {
        "Sid" : "ConfigWrite",
        "Effect" : "Allow",
        "Principal" : { "Service" : "config.amazonaws.com" },
        "Action" : "s3:PutObject",
        "Resource" : "${aws_s3_bucket.logs.arn}/config/AWSLogs/${data.aws_caller_identity.current.account_id}/*",
        "Condition" : {
          "StringEquals" : { "s3:x-amz-acl" : "bucket-owner-full-control" }
        }
      }
    ]
  })

  lifecycle {
    ignore_changes = all
  }

}

# --------------------------------------------------------------------

resource "aws_s3_bucket" "static" {
  bucket        = "${var.name_prefix}-static"
  force_destroy = true
  tags          = local.tags

  lifecycle {
    ignore_changes = [
      force_destroy,
      tags,
    ]
  }

}

# Default SSE-KMS on static bucket (BYOK)
resource "aws_s3_bucket_server_side_encryption_configuration" "static" {
  bucket = aws_s3_bucket.static.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_byok_arn
    }
  }
}
