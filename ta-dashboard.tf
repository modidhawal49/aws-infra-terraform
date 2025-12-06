########################################################
# CloudWatch Dashboard for TA overview
########################################################
resource "aws_cloudwatch_dashboard" "ta_overview" {
  dashboard_name = "${var.name_prefix}-ta-overview"
  dashboard_body = jsonencode({
    widgets = concat(
      [
        # RedResources per region
        for r in var.ta_regions : {
          "type" : "metric",
          "x" : 0, "y" : 0, "width" : 12, "height" : 6,
          "properties" : {
            "title" : "TA RedResources - ${r}",
            "metrics" : [
              [ "AWS/TrustedAdvisor", "RedResources", "Region", r ]
            ],
            "stat" : "Maximum",
            "period" : 300,
            "view" : "singleValue",
            "region" : var.aws_region
          }
        }
      ],
      [
        # YellowResources per region
        for r in var.ta_regions : {
          "type" : "metric",
          "x" : 12, "y" : 0, "width" : 12, "height" : 6,
          "properties" : {
            "title" : "TA YellowResources - ${r}",
            "metrics" : [
              [ "AWS/TrustedAdvisor", "YellowResources", "Region", r ]
            ],
            "stat" : "Maximum",
            "period" : 300,
            "view" : "singleValue",
            "region" : var.aws_region
          }
        }
      ]
    )
  })
}

# region variable (if you don't already have one)
variable "aws_region" {
  type        = string
  description = "Primary AWS region for dashboard rendering"
  default     = "me-central-1"
}

