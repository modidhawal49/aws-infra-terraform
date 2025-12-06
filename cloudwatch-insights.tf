############################################
# EKS Container Insights log groups (365d)
############################################

locals {
  ci_prefix = "/aws/containerinsights/${module.eks.cluster_name}"
  ci_groups = toset([
    "${local.ci_prefix}/application",
    "${local.ci_prefix}/dataplane",
    "${local.ci_prefix}/host"
  ])
}

resource "aws_cloudwatch_log_group" "ci" {
  for_each          = local.ci_groups
  name              = each.value
  retention_in_days = 365
  tags              = local.tags
}
