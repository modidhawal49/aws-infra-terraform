# Enroll this account (or management + all members, see below)
resource "aws_computeoptimizer_enrollment_status" "this" {
  status = "Active"

  # If this is the ORG management account and you want org-wide opt-in:
  # include_member_accounts = true
}

