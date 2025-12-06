############################################
# EKS Cluster
############################################
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.17"

  cluster_name    = "${var.name_prefix}-eks"
  cluster_version = var.eks_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # Enable IRSA (OIDC provider) for service accounts
  enable_irsa = true

  # Make the caller (cluster creator) an admin in cluster RBAC
  enable_cluster_creator_admin_permissions = false

  # Public API for now; tighten later
  cluster_endpoint_public_access       = true
  cluster_endpoint_private_access      = true
  cluster_endpoint_public_access_cidrs = var.eks_api_cidrs

  bootstrap_self_managed_addons = false

  # ✅ Control-plane logs -> CloudWatch Logs
  cluster_enabled_log_types              = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  create_cloudwatch_log_group            = true
  cloudwatch_log_group_retention_in_days = 30
  # cloudwatch_log_group_kms_key_id        = aws_kms_key.logs.arn # (optional)

  eks_managed_node_group_defaults = {
    lifecycle = {
      ignore_changes = [
        "node_group_name",
        "node_group_name_prefix",
        "launch_template",
        "labels",
        "tags",
        "tags_all",
        "update_config",
        "node_repair_config",
        "scaling_config",
        "disk_size",
        "instance_types",
      ]
    }
  }

  eks_managed_node_groups = {
    ng_ewec_nonprod = {
      ami_type                      = var.eks_ami_type
      desired_size                  = var.eks_ng_ewec_nonprod_desired
      min_size                      = var.eks_ng_ewec_nonprod_min
      max_size                      = var.eks_ng_ewec_nonprod_max
      instance_types                = var.eks_instance_types
      subnet_ids                    = module.vpc.private_subnets
      additional_security_group_ids = [aws_security_group.eks_nodes.id]
    }
  }

  tags = local.tags
}
# ----------------------------------------------------------------------
# IAM Policy attachment for Compute Optimizer (console-added)
# ----------------------------------------------------------------------
resource "aws_iam_role_policy_attachment" "cluster_compute_optimizer_ro" {
  role       = module.eks.cluster_iam_role_name
  policy_arn = "arn:aws:iam::aws:policy/ComputeOptimizerReadOnlyAccess"
}

############################################
# EKS Data Sources + Short Wait
############################################
data "aws_eks_cluster" "this" {
  name       = module.eks.cluster_name
  depends_on = [module.eks]

}

data "aws_eks_cluster_auth" "this" {
  name       = module.eks.cluster_name
  depends_on = [module.eks]
}

# Give the API a moment to accept writes
resource "time_sleep" "wait_for_eks_api" {
  depends_on      = [module.eks]
  create_duration = "60s"

  lifecycle {
    ignore_changes = [
      triggers,
    ]
  }

}

############################################
# IRSA Role for AWS Load Balancer Controller
############################################
module "eks_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name_prefix                       = "${var.name_prefix}-alb-controller"
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }

  tags = local.tags
}

############################################
# Managed EKS Add-ons
############################################
resource "aws_eks_addon" "vpc_cni" {
  cluster_name = module.eks.cluster_name
  addon_name   = "vpc-cni"
}

resource "aws_eks_addon" "coredns" {
  cluster_name                = module.eks.cluster_name
  addon_name                  = "coredns"
  resolve_conflicts_on_update = "OVERWRITE"
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name = module.eks.cluster_name
  addon_name   = "kube-proxy"
}

############################################
# AWS Load Balancer Controller (Helm via IRSA)
############################################
resource "helm_release" "alb_controller" {
  count      = 0
  provider   = helm.eks
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.9.0" # ensure compatibility with your EKS version

  values = [
    yamlencode({
      clusterName = module.eks.cluster_name
      serviceAccount = {
        create = true
        name   = "aws-load-balancer-controller"
        annotations = {
          "eks.amazonaws.com/role-arn" = module.eks_irsa.iam_role_arn
        }
      }
      region = var.region
      vpcId  = module.vpc.vpc_id
    })
  ]

  depends_on = [
    time_sleep.wait_for_eks_api,
    aws_eks_addon.vpc_cni,
    aws_eks_addon.coredns,
    aws_eks_addon.kube_proxy,
    module.eks_irsa
  ]

  lifecycle {
    prevent_destroy = true
  }

}

############################################
# IRSA Role for EFS CSI Driver
############################################
module "eks_irsa_efs" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name_prefix      = "${var.name_prefix}-efs-csi"
  attach_efs_csi_policy = false

  oidc_providers = {
    main = {
      provider_arn = module.eks.oidc_provider_arn
      # The AWS-managed EFS CSI add-on uses this SA
      namespace_service_accounts = ["kube-system:efs-csi-controller-sa"]
    }
  }

  tags = local.tags
}

# 🔒 Attach the AWS-managed policy for EFS CSI
resource "aws_iam_role_policy_attachment" "efs_csi_managed" {
  role       = module.eks_irsa_efs.iam_role_name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEFSCSIDriverPolicy"
}

############################################
# EKS Add-on: AWS EFS CSI Driver
############################################
resource "aws_eks_addon" "efs_csi" {
  cluster_name             = module.eks.cluster_name
  addon_name               = "aws-efs-csi-driver"
  service_account_role_arn = module.eks_irsa_efs.iam_role_arn

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [
    time_sleep.wait_for_eks_api,
    aws_eks_addon.vpc_cni,
    aws_eks_addon.coredns,
    aws_eks_addon.kube_proxy,
    aws_iam_role_policy_attachment.efs_csi_managed
  ]
}

############################################
# CloudWatch for Application & Node Logs
############################################
resource "aws_cloudwatch_log_group" "eks_app" {
  name              = "/aws/eks/${var.name_prefix}-eks/application"
  retention_in_days = 30
  tags              = local.tags
}
