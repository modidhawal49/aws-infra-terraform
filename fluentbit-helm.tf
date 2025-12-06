resource "helm_release" "fluent_bit" {
  count      = 0
  provider   = helm.eks
  name       = "aws-for-fluent-bit"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-for-fluent-bit"
  namespace  = "kube-system"

  values = [templatefile("${path.module}/fluentbit-values.yaml", {
    region        = var.region # or var.aws_region (see note below)
    cluster_name  = module.eks.cluster_name
    log_retention = 30
    role_arn      = aws_iam_role.fluentbit.arn
  })]

  depends_on = [
    time_sleep.wait_for_eks_api, # ensure API is ready
    aws_cloudwatch_log_group.eks_workloads,
    aws_iam_role.fluentbit
  ]

  lifecycle {
    ignore_changes = all
  }
}
