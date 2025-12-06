# App/workload log group (separate from control-plane log group in eks.tf)
resource "aws_cloudwatch_log_group" "eks_workloads" {
  name              = "/aws/eks/${module.eks.cluster_name}/workloads"
  retention_in_days = 30
  #kms_key_id        = aws_kms_key.logs.arn
  kms_key_id = var.kms_byok_arn
  tags              = local.tags

  depends_on = [aws_kms_key_policy.byok]

}
