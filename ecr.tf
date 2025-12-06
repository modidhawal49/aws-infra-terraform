resource "aws_ecr_repository" "app" {
  name = "${var.name_prefix}-app"
  image_scanning_configuration { scan_on_push = true }

  #encryption_configuration {
  #  encryption_type = "KMS"
  #  kms_key         = var.kms_byok_arn
  #}

  encryption_configuration { encryption_type = "KMS" }
  tags = local.tags
}

