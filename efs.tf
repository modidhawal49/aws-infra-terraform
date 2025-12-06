############################################
# EFS: filesystem + per-AZ mount targets
############################################
resource "aws_efs_file_system" "this" {
  creation_token = "${var.name_prefix}-efs"
  encrypted      = true
  #kms_key_id     = aws_kms_key.efs.arn
  kms_key_id = var.kms_byok_arn

  # Move cold data to IA based on your var
  lifecycle_policy {
    transition_to_ia = var.efs_transition_to_ia
  }

  # Optional defaults (safe for most workloads)
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"

  lifecycle {
    ignore_changes = all
  }

  tags = merge(local.tags, { Name = "${var.name_prefix}-efs" })
}

# --- Choose exactly one private/app subnet per AZ (same AZs as your nodes) ---
# We look up each private subnet to learn its AZ, then keep the first subnet per AZ.
data "aws_subnet" "priv" {
  for_each = { for id in module.vpc.private_subnets : id => id }
  id       = each.value
}

locals {
  # Map: AZ => [subnet_ids...]
  _priv_az_groups = {
    for _, s in data.aws_subnet.priv : s.availability_zone => s.id...
  }
  # Pick one subnet per AZ
  private_subnet_per_az = {
    for az, ids in local._priv_az_groups : az => ids[0]
  }
}

# One Mount Target per AZ (required for reliable cross-AZ mounting)
resource "aws_efs_mount_target" "mt" {
  for_each        = local.private_subnet_per_az
  file_system_id  = aws_efs_file_system.this.id
  subnet_id       = each.value
  security_groups = [aws_security_group.efs.id]
}

############################################
# EFS Access Points (app/data)
############################################
resource "aws_efs_access_point" "dev" {
  file_system_id = aws_efs_file_system.this.id

  posix_user {
    uid = 1000
    gid = 1000
  }

  root_directory {
    path = "/dev"
    creation_info {
      owner_uid   = 1000
      owner_gid   = 1000
      permissions = "0755"
    }
  }

  tags = merge(local.tags, { Name = "${var.name_prefix}-ap-dev" })
}


resource "aws_efs_access_point" "uat" {
  file_system_id = aws_efs_file_system.this.id

  posix_user {
    uid = 1000
    gid = 1000
  }

  root_directory {
    path = "/uat"
    creation_info {
      owner_uid   = 1000
      owner_gid   = 1000
      permissions = "0755"
    }
  }

  tags = merge(local.tags, { Name = "${var.name_prefix}-ap-uat" })
}

resource "aws_efs_access_point" "qa" {
  file_system_id = aws_efs_file_system.this.id

  posix_user {
    uid = 1000
    gid = 1000
  }

  root_directory {
    path = "/qa"
    creation_info {
      owner_uid   = 1000
      owner_gid   = 1000
      permissions = "0755"
    }
  }

  tags = merge(local.tags, { Name = "${var.name_prefix}-ap-qa" })
}
