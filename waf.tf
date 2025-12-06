###############################################################################
# Web ACL for ALB
###############################################################################
resource "aws_wafv2_web_acl" "alb" {
  name  = "${var.name_prefix}-waf"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.name_prefix}-waf"
    sampled_requests_enabled   = true
  }

  ###########################################################################
  # Rule 0: Explicit allow for Pimcore asset upload endpoint
  ###########################################################################
  rule {
    name     = "AllowPimcoreAssetUpload"
    priority = 0

    action {
      allow {}
    }

    statement {
      byte_match_statement {
        field_to_match {
          uri_path {}
        }
        positional_constraint = "STARTS_WITH"
        search_string         = "/admin/asset/add-asset"
        text_transformation {
          priority = 0
          type     = "NONE"
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "allow-pimcore-asset-upload"
      sampled_requests_enabled   = true
    }
  }

  ###########################################################################
  # Rule 1: Common OWASP protections
  ###########################################################################
  rule {
    name     = "AWS-AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "common"
      sampled_requests_enabled   = true
    }
  }

  ###########################################################################
  # Rule 2: Bot Control (Bot Manager)
  ###########################################################################
  rule {
    name     = "AWS-AWSManagedRulesBotControlRuleSet"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesBotControlRuleSet"
        vendor_name = "AWS"

        scope_down_statement {
          or_statement {
            statement {
              byte_match_statement {
                field_to_match {
                  uri_path {}
                }
                positional_constraint = "STARTS_WITH"
                search_string         = "/login"
                text_transformation {
                  priority = 0
                  type     = "NONE"
                }
              }
            }
            statement {
              byte_match_statement {
                field_to_match {
                  uri_path {}
                }
                positional_constraint = "STARTS_WITH"
                search_string         = "/cart"
                text_transformation {
                  priority = 0
                  type     = "NONE"
                }
              }
            }
          }
        }

        managed_rule_group_configs {
          aws_managed_rules_bot_control_rule_set {
            inspection_level = "COMMON"
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "bot-control"
      sampled_requests_enabled   = true
    }
  }

  tags = local.tags

  lifecycle {
    ignore_changes = [
      rule,
    ]
  }

}
