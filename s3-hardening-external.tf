############################################
# HTTPS-only + Public Access Block
# for buckets not defined in Terraform
############################################

# ---------- ewec-prod-static ----------
resource "aws_s3_bucket_public_access_block" "ewec_prod_static" {
  bucket                      = "ewec-prod-static"
  block_public_acls           = true
  block_public_policy         = true
  ignore_public_acls          = true
  restrict_public_buckets     = true
}

data "aws_iam_policy_document" "deny_non_tls_ewec_prod_static" {
  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    resources = [
      "arn:aws:s3:::ewec-prod-static",
      "arn:aws:s3:::ewec-prod-static/*"
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  # Allow list on the bucket itself
  statement {
    sid    = "AllowBucketList"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]

    }

    actions   = ["s3:ListBucket"]
    resources = ["arn:aws:s3:::ewec-prod-static"]
  }

  # Allow object-level access
  statement {
    sid    = "AllowObjectAccess"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }

    actions = [
      "s3:GetObject",
      "s3:GetObjectAcl",
      "s3:PutObject",
      "s3:PutObjectAcl",
      "s3:ReplicateObject",
      "s3:DeleteObject"
    ]

    resources = ["arn:aws:s3:::ewec-prod-static/*"]
  }
}

resource "aws_s3_bucket_policy" "ewec_prod_static" {
  bucket     = "ewec-prod-static"
  policy     = data.aws_iam_policy_document.deny_non_tls_ewec_prod_static.json
  depends_on = [aws_s3_bucket_public_access_block.ewec_prod_static]
}

# ---------- ewec-credencys-infra ----------
resource "aws_s3_bucket_public_access_block" "ewec_credencys_infra" {
  bucket                      = "ewec-credencys-infra"
  block_public_acls           = true
  block_public_policy         = true
  ignore_public_acls          = true
  restrict_public_buckets     = true
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
resource "aws_s3_bucket_versioning" "ewec_prod_static" {
  bucket = "ewec-prod-static"
  versioning_configuration {
    status = "Enabled"
  }
}

