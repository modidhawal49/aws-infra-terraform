############################################
# EFS: filesystem + per-AZ mount targets
############################################

resource "aws_efs_file_system" "this" {
  creation_token = "${var.name_prefix}-efs"
  encrypted      = true
  kms_key_id     = aws_kms_key.efs.arn

  # Include lifecycle policy only if provided
  dynamic "lifecycle_policy" {
    for_each = var.efs_transition_to_ia == null ? [] : [1]
    content {
      transition_to_ia = var.efs_transition_to_ia
    }
  }

  # Safe defaults
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"

  tags = merge(local.tags, { Name = "${var.name_prefix}-efs" })
}

############################################
# Private subnets → static-key map (plan-safe)
############################################
# Create a map with stable, static keys so for_each can plan
locals {
  # Convert the (unknown at plan) tuple to a list and index it
  # Keys are static strings "0","1",... while values are the subnet IDs
  priv_subnets_indexed = {
    for idx, id in tolist(module.vpc.private_subnets) :
    tostring(idx) => id
  }
}

############################################
# Mount Targets (1 per private subnet / AZ)
############################################
resource "aws_efs_mount_target" "mt" {
  for_each        = local.priv_subnets_indexed
  file_system_id  = aws_efs_file_system.this.id
  subnet_id       = each.value
  security_groups = [aws_security_group.efs.id]

  # Helps Terraform understand ordering if the VPC module computes outputs
  depends_on = [module.vpc]
}

############################################
# EFS Access Points (example: /prod)
############################################
resource "aws_efs_access_point" "prod" {
  file_system_id = aws_efs_file_system.this.id

  posix_user {
    uid = 1000
    gid = 1000
  }

  root_directory {
    path = "/prod"
    creation_info {
      owner_uid   = 1000
      owner_gid   = 1000
      permissions = "0755"
    }
  }

  tags = merge(local.tags, { Name = "${var.name_prefix}-ap-prod" })
}

