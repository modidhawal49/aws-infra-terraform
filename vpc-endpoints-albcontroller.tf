############################################
# Allow nodes to reach VPC Endpoints on 443
# (Skip if you already have this rule)
############################################
resource "aws_security_group_rule" "vpce_in_443_from_nodes" {
  count                    = 0
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.vpce.id
  source_security_group_id = aws_security_group.eks_nodes.id
  description              = "Allow EKS nodes to access Interface VPC Endpoints"
}

############################################
# Interface Endpoints required by ALB Controller
############################################
locals {
  alb_controller_vpce_services = toset([
    "sts",                  # IRSA / AssumeRoleWithWebIdentity
    "elasticloadbalancing", # create/manage ALB/TGs
    "ec2",                  # describe subnets/SGs, etc.
    "acm",                  # certificate lookups
    "wafv2"                 # associate WebACL
  ])
}

resource "aws_vpc_endpoint" "alb_controller_interfaces" {
  for_each            = local.alb_controller_vpce_services
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${var.region}.${each.key}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.private_subnets
  security_group_ids  = [aws_security_group.vpce.id]
  private_dns_enabled = true

  tags = merge(local.tags, { Name = "${var.name_prefix}-vpce-${each.key}" })
}

