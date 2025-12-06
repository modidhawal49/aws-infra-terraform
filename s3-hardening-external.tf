# ---------- ewec-nonprod-static ----------
resource "aws_s3_bucket_public_access_block" "ewec_nonprod_static" {
  bucket             = "ewec-nonprod-static"
  block_public_acls  = true
  ignore_public_acls = true

  # allow a bucket policy with public read on assets/* to be honored
  block_public_policy     = false
  restrict_public_buckets = false

  lifecycle {
    ignore_changes = [
      block_public_policy,
      restrict_public_buckets,
      ignore_public_acls,
      block_public_acls,
    ]
  }

}

data "aws_iam_policy_document" "deny_non_tls_ewec_nonprod_static" {
  # 1) Enforce HTTPS for all requests to the bucket
  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    resources = [
      "arn:aws:s3:::ewec-nonprod-static",
      "arn:aws:s3:::ewec-nonprod-static/*"
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  # 2) Enforce KMS and this specific CMK for writes
  statement {
    sid     = "DenyUnencryptedOrWrongKey"
    effect  = "Deny"
    actions = ["s3:PutObject"]
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    resources = ["arn:aws:s3:::ewec-nonprod-static/*"]

    condition {
      test     = "StringNotEquals"
      variable = "s3:x-amz-server-side-encryption"
      values   = ["aws:kms"]
    }

    condition {
      test     = "StringNotEquals"
      variable = "s3:x-amz-server-side-encryption-aws-kms-key-id"
      values   = [var.kms_byok_arn]
    }
  }

  # 2b) Deny non-KMS or wrong-KMS PUTs (enforce SSE-KMS with your BYOK)
  statement {
    sid     = "DenyPutWithoutKMS"
    effect  = "Deny"
    actions = ["s3:PutObject"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    resources = [
      "arn:aws:s3:::ewec-nonprod-static/*"
    ]

    condition {
      test     = "StringNotEquals"
      variable = "s3:x-amz-server-side-encryption"
      values   = ["aws:kms"]
    }

    condition {
      test     = "StringNotEquals"
      variable = "s3:x-amz-server-side-encryption-aws-kms-key-id"
      values   = [var.kms_byok_arn]
    }
  }


  # 2) Restore your IAM user's bucket-level access (ListBucket)
  statement {
    sid     = "AllowSpecificUserAccess"
    effect  = "Allow"
    actions = ["s3:ListBucket"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::035838344560:user/ewec-nonProd-s3-access"]
    }

    resources = [
      "arn:aws:s3:::ewec-nonprod-static"
    ]
  }

  # 3) Restore your IAM user's object-level access
  statement {
    sid    = "AllowSpecificUserObjects"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:GetObjectAcl",
      "s3:PutObject",
      "s3:PutObjectAcl",
      "s3:ReplicateObject",
      "s3:DeleteObject"
    ]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::035838344560:user/ewec-nonProd-s3-access"]
    }

    resources = [
      "arn:aws:s3:::ewec-nonprod-static",
      "arn:aws:s3:::ewec-nonprod-static/*"
    ]
  }

  # 4) Keep public read for assets/* — but only over HTTPS
  statement {
    sid     = "AllowPublicReadExportFolder"
    effect  = "Allow"
    actions = ["s3:GetObject"]

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    resources = [
      "arn:aws:s3:::ewec-nonprod-static/assets/*"
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["true"]
    }
  }
}

resource "aws_s3_bucket_policy" "ewec_nonprod_static" {
  bucket     = "ewec-nonprod-static"
  policy     = data.aws_iam_policy_document.deny_non_tls_ewec_nonprod_static.json
  depends_on = [aws_s3_bucket_public_access_block.ewec_nonprod_static]

  lifecycle {
    ignore_changes = [
      policy
    ]
  }

}


# ---------- ewec-credencys-infra ----------
resource "aws_s3_bucket_public_access_block" "ewec_credencys_infra" {
  bucket                  = "ewec-credencys-infra"
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

data "aws_iam_policy_document" "deny_non_tls_ewec_credencys_infra" {
  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    resources = [
      "arn:aws:s3:::ewec-credencys-infra",
      "arn:aws:s3:::ewec-credencys-infra/*"
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "ewec_credencys_infra" {
  bucket     = "ewec-credencys-infra"
  policy     = data.aws_iam_policy_document.deny_non_tls_ewec_credencys_infra.json
  depends_on = [aws_s3_bucket_public_access_block.ewec_credencys_infra]
}

# ---------- ewec-prod-static : Versioning ----------
resource "aws_s3_bucket_versioning" "ewec_nonprod_static" {
  bucket = "ewec-nonprod-static"
  versioning_configuration {
    status = "Enabled"
  }
}
