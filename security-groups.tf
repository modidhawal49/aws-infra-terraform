# VPCE SG (allow 443 from VPC)
resource "aws_security_group" "vpce" {
  name        = "${var.name_prefix}-vpce-sg"
  description = "VPCE interface endpoints"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.tags

  lifecycle {
    ignore_changes = [
      ingress,
    ]
  }

}

# ALB SG
resource "aws_security_group" "alb" {
  name   = "${var.name_prefix}-alb-sg"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.tags
}

# EKS Nodes SG (ingress from ALB, VPC; egress to DB/Redis/EFS/VPCE/NAT)
resource "aws_security_group" "eks_nodes" {
  name   = "${var.name_prefix}-eks-nodes-sg"
  vpc_id = module.vpc.vpc_id

  # From ALB
  ingress {
    description     = "ALB to Nodes (HTTP)"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    description = "VPC internal pod2pod"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # ✅ NEW: UDP 53 for DNS to CoreDNS
  ingress {
    description = "VPC internal pod2pod DNS (UDP)"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Nodeports / kubelet etc (managed by EKS module too)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.tags

  lifecycle {
    ignore_changes = [ingress]
  }

}

# Ingress Controller target SG attached to EKS service (for ALB targets)
resource "aws_security_group" "eks_ingress" {
  name   = "${var.name_prefix}-ingress-target-sg"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.tags
}

# RDS SG (allow 3306 from EKS nodes SG)
resource "aws_security_group" "rds" {
  name   = "${var.name_prefix}-rds-sg"
  vpc_id = module.vpc.vpc_id

  ingress {
    description     = "EKS to RDS"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_nodes.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    ignore_changes = [ingress, egress]
  }

  tags = local.tags
}

# Redis SG (6379/6380 from EKS)
resource "aws_security_group" "redis" {
  name   = "${var.name_prefix}-redis-sg"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_nodes.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.tags

  lifecycle {
    ignore_changes = [
      ingress,
    ]
  }

}

# EFS SG (2049 from EKS)
resource "aws_security_group" "efs" {
  name   = "${var.name_prefix}-efs-sg"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_nodes.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.tags
}

# Allow from the EKS module's node security group (primary SG of the nodes)
resource "aws_security_group_rule" "rds_from_eks_module_nodesg" {
  type                     = "ingress"
  description              = "MySQL from EKS module node SG"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  security_group_id        = aws_security_group.rds.id
  source_security_group_id = module.eks.node_security_group_id
}

resource "aws_security_group_rule" "redis_from_eks_module_nodesg" {
  type                     = "ingress"
  description              = "Redis from EKS module node SG"
  from_port                = var.redis_port
  to_port                  = var.redis_port
  protocol                 = "tcp"
  security_group_id        = aws_security_group.redis.id
  source_security_group_id = aws_security_group.eks_nodes.id
}

resource "aws_security_group_rule" "redis_from_eks_module" {
  type                     = "ingress"
  from_port                = 6379
  to_port                  = 6379
  protocol                 = "tcp"
  security_group_id        = aws_security_group.redis.id
  source_security_group_id = module.eks.node_security_group_id
}

# EKS nodes SG: allow DNS from VPC (UDP)
resource "aws_security_group_rule" "eks_nodes_in_dns_udp" {
  type                     = "ingress"
  description              = "VPC internal DNS (UDP 53) to nodes"
  from_port                = 53
  to_port                  = 53
  protocol                 = "udp"
  security_group_id        = aws_security_group.eks_nodes.id
  cidr_blocks              = [var.vpc_cidr]
}

# EKS nodes SG: allow DNS from VPC (TCP fallback)
resource "aws_security_group_rule" "eks_nodes_in_dns_tcp" {
  type                     = "ingress"
  description              = "VPC internal DNS (TCP 53) to nodes"
  from_port                = 53
  to_port                  = 53
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_nodes.id
  cidr_blocks              = [var.vpc_cidr]
}
