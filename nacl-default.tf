############################################################
# Lock down the VPC's *default* Network ACL
# - Deny all ingress and egress
# - This satisfies scanners even if the default NACL is unused
############################################################

# We need the default NACL ID from the VPC module
# (terraform-aws-modules/vpc outputs this value)
resource "aws_default_network_acl" "this" {
  default_network_acl_id = module.vpc.default_network_acl_id

  # OPTIONAL: list subnets here only if you intentionally
  # want the default NACL on any subnets (you don't).
  # Keeping it empty means it won't be associated to your subnets.
  # subnet_ids = []

  tags = merge(local.tags, { Name = "${var.name_prefix}-nacl-default-locked" })

  # Ingress: explicit DENY ALL
  ingress {
    rule_no    = 100
    protocol   = "-1"
    action     = "deny"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  # Egress: explicit DENY ALL
  egress {
    rule_no    = 100
    protocol   = "-1"
    action     = "deny"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  lifecycle {
    ignore_changes = [
      ingress,
      egress,
    ]
  }

}
