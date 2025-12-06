############################################################
# Network ACLs
# - Public: ALB subnets
# - App/Private: EKS node/pod subnets (egress via NAT)
# - Data/DB: RDS/ElastiCache subnets
############################################################

locals {
  # Convenience handles to subnet CIDR blocks
  public_cidrs  = try(module.vpc.public_subnets_cidr_blocks,  [])
  app_cidrs     = try(module.vpc.private_subnets_cidr_blocks, [])
  data_cidrs    = try(module.vpc.database_subnets_cidr_blocks, [])

  # Common ports
  ephemeral_from = 1024
  ephemeral_to   = 65535
}

#########################
# PUBLIC SUBNET NACL
#########################
resource "aws_network_acl" "public" {
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.public_subnets
  tags       = merge(local.tags, { Name = "${var.name_prefix}-nacl-public" })
}

# Inbound 80 (HTTP) from Internet
resource "aws_network_acl_rule" "public_in_80" {
  network_acl_id = aws_network_acl.public.id
  rule_number    = 100
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 80
  to_port        = 80
}

# Inbound 443 (HTTPS) from Internet
resource "aws_network_acl_rule" "public_in_443" {
  network_acl_id = aws_network_acl.public.id
  rule_number    = 110
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 443
  to_port        = 443
}

# UDP EPHEMERAL IN (DNS replies back to client ephemeral port)
resource "aws_network_acl_rule" "app_in_ephemeral_udp" {
  network_acl_id = aws_network_acl.app.id
  rule_number    = 111
  egress         = false
  protocol       = "udp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 1024
  to_port        = 65535
}

# Inbound Ephemeral (return traffic)
resource "aws_network_acl_rule" "public_in_ephemeral" {
  network_acl_id = aws_network_acl.public.id
  rule_number    = 120
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = local.ephemeral_from
  to_port        = local.ephemeral_to
}

# Outbound 80/443 to Internet
resource "aws_network_acl_rule" "public_out_80_443" {
  network_acl_id = aws_network_acl.public.id
  rule_number    = 100
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 80
  to_port        = 443
}

# Outbound Ephemeral
resource "aws_network_acl_rule" "public_out_ephemeral" {
  network_acl_id = aws_network_acl.public.id
  rule_number    = 110
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = local.ephemeral_from
  to_port        = local.ephemeral_to
}

#########################
# APP / PRIVATE SUBNET NACL (EKS nodes/pods)
#########################
resource "aws_network_acl" "app" {
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets
  tags       = merge(local.tags, { Name = "${var.name_prefix}-nacl-app" })
}

# Inbound: allow ALB (public subnets) -> pods on HTTP/80
# Creates one rule per public subnet CIDR with unique rule numbers.
resource "aws_network_acl_rule" "app_in_80_from_public" {
  for_each       = { for idx, cidr in local.public_cidrs : tostring(idx) => cidr }

  network_acl_id = aws_network_acl.app.id
  rule_number    = 80 + tonumber(each.key)   # 80,81,82... (below your 90/95/100 rules)
  egress         = false
  protocol       = "6"                       # TCP
  rule_action    = "allow"
  cidr_block     = each.value
  from_port      = 80
  to_port        = 80
}

# Inbound: allow HTTPS (443) from VPC (control plane → nodes)
resource "aws_network_acl_rule" "app_in_443" {
  network_acl_id = aws_network_acl.app.id
  rule_number    = 90
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = module.vpc.vpc_cidr_block
  from_port      = 443
  to_port        = 443
}

# Inbound: allow DNS responses
resource "aws_network_acl_rule" "app_in_dns" {
  network_acl_id = aws_network_acl.app.id
  rule_number    = 95
  egress         = false
  protocol       = "udp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 53
  to_port        = 53
}

# Inbound: allow ephemeral return traffic
resource "aws_network_acl_rule" "app_in_ephemeral" {
  network_acl_id = aws_network_acl.app.id
  rule_number    = 100
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = local.ephemeral_from
  to_port        = local.ephemeral_to
}

# Outbound: allow DNS queries
resource "aws_network_acl_rule" "app_out_dns" {
  network_acl_id = aws_network_acl.app.id
  rule_number    = 85
  egress         = true
  protocol       = "udp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 53
  to_port        = 53
}

# Outbound: allow HTTPS/HTTP to Internet
resource "aws_network_acl_rule" "app_out_80_443" {
  network_acl_id = aws_network_acl.app.id
  rule_number    = 90
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 80
  to_port        = 443
}

# Outbound: allow ephemeral
resource "aws_network_acl_rule" "app_out_ephemeral" {
  network_acl_id = aws_network_acl.app.id
  rule_number    = 100
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = local.ephemeral_from
  to_port        = local.ephemeral_to
}

# Outbound: allow to DB/Cache subnets
resource "aws_network_acl_rule" "app_out_db_mysql" {
  network_acl_id = aws_network_acl.app.id
  rule_number    = 120
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = length(local.data_cidrs) > 0 ? local.data_cidrs[0] : module.vpc.vpc_cidr_block
  from_port      = 3306
  to_port        = 3306
}

resource "aws_network_acl_rule" "app_out_db_redis" {
  network_acl_id = aws_network_acl.app.id
  rule_number    = 130
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = length(local.data_cidrs) > 0 ? local.data_cidrs[0] : module.vpc.vpc_cidr_block
  from_port      = 6379
  to_port        = 6379
}

#########################
# DATA / DB SUBNET NACL (RDS, ElastiCache)
#########################
resource "aws_network_acl" "data" {
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.database_subnets
  tags       = merge(local.tags, { Name = "${var.name_prefix}-nacl-data" })
}

# Inbound from App subnets to MySQL (3306)
resource "aws_network_acl_rule" "data_in_mysql" {
  network_acl_id = aws_network_acl.data.id
  rule_number    = 100
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = length(local.app_cidrs) > 0 ? local.app_cidrs[0] : module.vpc.vpc_cidr_block
  from_port      = 3306
  to_port        = 3306
}

# Inbound from App subnets to Redis (6379)
resource "aws_network_acl_rule" "data_in_redis" {
  network_acl_id = aws_network_acl.data.id
  rule_number    = 110
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = length(local.app_cidrs) > 0 ? local.app_cidrs[0] : module.vpc.vpc_cidr_block
  from_port      = 6379
  to_port        = 6379
}

# Inbound Ephemeral (responses back to App)
resource "aws_network_acl_rule" "data_in_ephemeral" {
  network_acl_id = aws_network_acl.data.id
  rule_number    = 120
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = length(local.app_cidrs) > 0 ? local.app_cidrs[0] : module.vpc.vpc_cidr_block
  from_port      = local.ephemeral_from
  to_port        = local.ephemeral_to
}

# Outbound Ephemeral (responses to App)
resource "aws_network_acl_rule" "data_out_ephemeral" {
  network_acl_id = aws_network_acl.data.id
  rule_number    = 100
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = length(local.app_cidrs) > 0 ? local.app_cidrs[0] : module.vpc.vpc_cidr_block
  from_port      = local.ephemeral_from
  to_port        = local.ephemeral_to
}

# ICMP OUT: allow echo requests to internet
resource "aws_network_acl_rule" "app_out_icmp_echo" {
  network_acl_id = aws_network_acl.app.id
  rule_number    = 70
  egress         = true
  protocol       = "icmp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  icmp_type      = 8   # echo request
  icmp_code      = 0
}

# ICMP IN: allow echo replies from internet
resource "aws_network_acl_rule" "app_in_icmp_echo_reply" {
  network_acl_id = aws_network_acl.app.id
  rule_number    = 110
  egress         = false
  protocol       = "icmp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  icmp_type      = 0   # echo reply
  icmp_code      = 0
}

# DNS over TCP OUT (complements your UDP/53 allow)
resource "aws_network_acl_rule" "app_out_dns_tcp" {
  network_acl_id = aws_network_acl.app.id
  rule_number    = 86
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 53
  to_port        = 53
}

# UDP EPHEMERAL OUT (client ports 1024–65535)
resource "aws_network_acl_rule" "app_out_ephemeral_udp" {
  network_acl_id = aws_network_acl.app.id
  rule_number    = 87
  egress         = true
  protocol       = "udp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 1024
  to_port        = 65535
}

# DNS over TCP IN (return)
resource "aws_network_acl_rule" "app_in_dns_tcp" {
  network_acl_id = aws_network_acl.app.id
  rule_number    = 96
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 53
  to_port        = 53
}

# ---- Auto-added with unique rule_number by assistant ----

resource "aws_network_acl_rule" "data_in_mysql_b" {
  rule_number    = 60
  network_acl_id = aws_network_acl.data.id
  rule_action    = "allow"
  egress         = false
  protocol       = "tcp"
  cidr_block     = "192.168.4.0/26"
  from_port      = 3306
  to_port        = 3306
}

resource "aws_network_acl_rule" "data_in_redis_b" {
  rule_number    = 61
  network_acl_id = aws_network_acl.data.id
  rule_action    = "allow"
  egress         = false
  protocol       = "tcp"
  cidr_block     = "192.168.4.0/26"
  from_port      = 6379
  to_port        = 6379
}

resource "aws_network_acl_rule" "data_out_ephemeral_to_priv_a" {
  rule_number    = 60
  network_acl_id = aws_network_acl.data.id
  rule_action    = "allow"
  egress         = true
  protocol       = "tcp"
  cidr_block     = "192.168.3.0/26"
  from_port      = 1024
  to_port        = 65535
}

resource "aws_network_acl_rule" "data_out_ephemeral_to_priv_b" {
  rule_number    = 61
  network_acl_id = aws_network_acl.data.id
  rule_action    = "allow"
  egress         = true
  protocol       = "tcp"
  cidr_block     = "192.168.4.0/26"
  from_port      = 1024
  to_port        = 65535
}
