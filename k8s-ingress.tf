#################################################
# Namespace (no app, no Service)
#################################################
resource "kubernetes_namespace_v1" "app" {
  count    = var.create_k8s_ingress ? 1 : 0
  provider  = kubernetes.eks
  metadata { name = "nginx-ingress" }
  depends_on = [time_sleep.wait_for_eks_api]

  lifecycle {
    prevent_destroy = true
    ignore_changes  = all
  }
}

#################################################
# Bootstrap Ingress -> provisions ALB only
# - Uses a fixed-response action (no TG yet)
# - Establishes stable ALB via group.name (and optional load-balancer-name)
#################################################
resource "kubernetes_ingress_v1" "alb_bootstrap" {
  count    = var.create_k8s_ingress ? 1 : 0
  provider  = kubernetes.eks

  metadata {
    name      = "alb-bootstrap"
    #namespace = kubernetes_namespace_v1.app.metadata[0].name
    namespace = kubernetes_namespace_v1.app[count.index].metadata[0].name

    annotations = {
      # Use ALB controller
      "kubernetes.io/ingress.class"               = "alb"

      # ALB settings
      "alb.ingress.kubernetes.io/scheme"          = "internet-facing"
      "alb.ingress.kubernetes.io/group.order"     = "999"
      "alb.ingress.kubernetes.io/target-type"     = "ip"
      "alb.ingress.kubernetes.io/listen-ports"    = "[{\"HTTP\":80},{\"HTTPS\":443}]"
      "alb.ingress.kubernetes.io/ssl-redirect"    = "443"
      "alb.ingress.kubernetes.io/certificate-arn" = var.alb_certificate_arn
      "alb.ingress.kubernetes.io/ssl-policy"      = var.alb_ssl_policy

      # Stable ALB across many ingresses
      "alb.ingress.kubernetes.io/group.name"      = var.alb_group_name

      # (Optional) Pick a stable LB name (must be unique in VPC)
      # "alb.ingress.kubernetes.io/load-balancer-name" = "${var.name_prefix}-shared-alb"

      # WAFv2 + Access logs
      "alb.ingress.kubernetes.io/wafv2-acl-arn"   = aws_wafv2_web_acl.alb.arn
      "alb.ingress.kubernetes.io/load-balancer-attributes" = "routing.http.drop_invalid_header_fields.enabled=true,access_logs.s3.enabled=true,access_logs.s3.bucket=${aws_s3_bucket.logs.bucket},access_logs.s3.prefix=${var.alb_logs_prefix}"

      # ---- Fixed response action so we don't need any Service/Pods yet ----
      # Create an ALB listener rule that simply returns 404 text until real apps arrive.
      "alb.ingress.kubernetes.io/actions.default-404" = jsonencode({
        Type = "fixed-response",
        FixedResponseConfig = {
          ContentType = "text/plain"
          StatusCode  = "404"
          MessageBody = "No backends registered yet"
        }
      })
    }
  }

  spec {
    # You can set this too; annotation above is sufficient for ALB controller
    ingress_class_name = "alb"

    rule {
      # If you plan to bind a real domain later, leave host null for now
      host = var.ingress_host != "" ? var.ingress_host : null

      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            # Special "use-annotation" trick: this references the fixed-response action
            service {
              name = "default-404"
              port {
                name = "use-annotation"
              }
            }
          }
        }
      }
    }
  }

  lifecycle {
    ignore_changes = all
  }

  depends_on = [kubernetes_namespace_v1.app]
}
