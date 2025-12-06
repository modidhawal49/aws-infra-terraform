#!/usr/bin/env bash
# Safe-mode Terraform import script (confirmation for each resource)
# Updated: 2025-11-21
#
# Purpose:
#  - Backup current state
#  - For each configured resource: show current state (if any), skip if already present,
#    otherwise prompt to remove state mapping and import the existing AWS resource.
#  - Detect remote backend lock and provide safe guidance (will NOT force-unlock automatically).
#
# Usage:
#  chmod +x ./import_prod_safe.sh
#  ./import_prod_safe.sh
#
# NOTES:
#  - This script performs only state operations: terraform state rm + terraform import.
#    It does NOT change your AWS resources.
#  - If the backend is locked you will be asked whether to proceed with -lock=false
#    or to skip and force-unlock manually (recommended if you are sure it's stale).
#  - The script uses -var-file=prod.tfvars during imports; change if your varfile differs.

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
TS=$(date +%Y%m%dT%H%M%S)
BACKUP="tfstate-backup-${TS}.json"
VARFILE="prod.tfvars"

# Colors for nicer prompts (optional; safe if not supported)
RED="$(tput setaf 1 2>/dev/null || true)"
GREEN="$(tput setaf 2 2>/dev/null || true)"
YELLOW="$(tput setaf 3 2>/dev/null || true)"
RESET="$(tput sgr0 2>/dev/null || true)"

echo "${GREEN}Backing up current terraform state to ${BACKUP}...${RESET}"
terraform state pull > "${BACKUP}"
echo "${GREEN}Backup saved at ${BACKUP}.${RESET}"
echo

echo "NOTE: terraform import ignores -var-file during import state mapping, but it's included for consistency."
echo "This script will prompt you before each 'state rm' + 'import'. Read the prompts carefully."
echo

confirm() {
  # $1 = prompt
  while true; do
    read -r -p "$1 (yes/no): " yn
    case "${yn,,}" in
      yes) return 0 ;;
      no)  return 1 ;;
      *) echo "Please answer yes or no." ;;
    esac
  done
}

# Check whether backend is reachable and not locked.
# We try 'terraform state pull' and capture errors. If it fails, we report it.
backend_health_check() {
  if terraform state pull >/dev/null 2>&1; then
    return 0
  else
    return 1
  fi
}

# Print safe guidance for force-unlock with the provided lock id (if known)
print_force_unlock_guidance() {
  local lock_id="$1"
  echo
  echo "${YELLOW}Backend appears locked. If you are certain the lock is stale (no one is running Terraform operations),${RESET}"
  echo "${YELLOW}you can remove it with:${RESET}"
  echo
  if [ -n "$lock_id" ]; then
    echo "  terraform force-unlock ${lock_id}"
  else
    echo "  terraform force-unlock <LOCK_ID>"
    echo "  (replace <LOCK_ID> with the id shown in Terraform's lock error)"
  fi
  echo
  echo "Be careful: running force-unlock while an apply is in progress may corrupt state."
  echo
}

# Main function used to show, optionally remove state and import
do_show_rm_import() {
  local addr="$1"
  local id="$2"
  local hint="$3"

  echo
  echo "================================================================"
  echo "Resource: $addr"
  echo "Planned import id/arn: $id"
  if [ -n "$hint" ]; then
    echo "Hint: $hint"
  fi
  echo

  # If the address is already in state, skip it (and show state)
  if terraform state list | grep -xqF "$addr"; then
    echo "${GREEN}(SKIP) Address $addr already present in state.${RESET}"
    echo
    echo "----- terraform state show $addr -----"
    terraform state show "$addr" || true
    echo "----- end state show -----"
    return 0
  fi

  # Backend health: check if locked/unreachable
  if ! backend_health_check; then
    echo "${RED}Terraform backend appears locked or unreachable.${RESET}"
    echo "Common cause: another terraform process (apply/plan) is running, or a stale lock exists in the S3 backend."
    echo
    print_force_unlock_guidance ""  # no lock id from here; user will have seen it in original error
    echo "Options:"
    echo "  1) Manually run the force-unlock command above (recommended if lock is stale)."
    echo "  2) Proceed with import using -lock=false (risky if someone else is writing state)."
    if confirm "Do you want to attempt to continue the import using -lock=false for this resource? (not recommended)"; then
      LOCK_OVERRIDE="-lock=false"
      echo "${YELLOW}Proceeding with -lock=false for this import. Make sure no other Terraform writer is active!${RESET}"
    else
      echo "Skipping $addr until lock is cleared."
      return 1
    fi
  else
    LOCK_OVERRIDE=""
  fi

  # If id is a placeholder, ask for actual id or allow skip
  if [[ "$id" == REPLACE_ME* ]]; then
    echo "This entry requires a real AWS id/arn (placeholder detected)."
    echo "Provide the ID/ARN now (or type 'skip' to skip this resource):"
    read -r USER_ID
    if [ "$USER_ID" = "skip" ]; then
      echo "Skipping $addr (user requested skip)."
      return 1
    fi
    id="$USER_ID"
  fi

  echo
  echo "Current state for $addr (if present):"
  if terraform state list | grep -xqF "$addr"; then
    terraform state show "$addr" || true
  else
    echo "(Address not present in current state)"
  fi
  echo

  echo "Commands that will be run (if you confirm):"
  echo "  terraform state rm '$addr' || true"
  echo "  terraform import ${LOCK_OVERRIDE} -var-file=${VARFILE} '$addr' '$id'"
  echo

  if confirm "Proceed with state rm + import for $addr?"; then
    echo "${YELLOW}Removing state mapping for $addr...${RESET}"
    terraform state rm "$addr" || true

    echo "${YELLOW}Importing $addr with id $id ...${RESET}"
    # Use eval to allow optional LOCK_OVERRIDE
    eval terraform import ${LOCK_OVERRIDE} -var-file="${VARFILE}" "\"${addr}\"" "\"${id}\""
    echo "${GREEN}Done importing $addr${RESET}"
    return 0
  else
    echo "Skipped $addr by user choice."
    return 1
  fi
}

# ---- Resource list derived from your prod terraform state list ----
# Each entry: do_show_rm_import '<terraform-address>' '<live-id-or-arn-or-REPLACE_ME>' '<optional-hint>'

do_show_rm_import 'aws_kms_alias.backup' 'alias/ewec-prod/backup' "alias name for backup KMS (alias/ewec-prod/backup)"
do_show_rm_import 'aws_kms_alias.cloudtrail' 'alias/ewec-prod/cloudtrail' "alias name for cloudtrail KMS"
do_show_rm_import 'aws_kms_alias.logs' 'alias/ewec-prod/cloudwatch-logs' "alias name for logs KMS"
do_show_rm_import 'aws_kms_alias.sns' 'alias/ewec-prod/sns' "alias for sns kms"

do_show_rm_import 'aws_kms_key.backup' 'REPLACE_ME_ARN_for_backup_key' "Get with: aws kms list-keys + aws kms describe-key"
do_show_rm_import 'aws_kms_key.cloudtrail' 'REPLACE_ME_ARN_for_cloudtrail_key' "Get with: aws kms list-keys + aws kms describe-key"
do_show_rm_import 'aws_kms_key.db' 'REPLACE_ME_ARN_for_db_key' "Get with: aws kms list-keys + aws kms describe-key"
do_show_rm_import 'aws_kms_key.efs' 'REPLACE_ME_ARN_for_efs_key' "Get with: aws kms list-keys + aws kms describe-key"
do_show_rm_import 'aws_kms_key.logs' 'REPLACE_ME_ARN_for_logs_key' "Get with: aws kms list-keys + aws kms describe-key"
do_show_rm_import 'aws_kms_key.sns' 'REPLACE_ME_ARN_for_sns_key' "Get with: aws kms list-keys + aws kms describe-key"
do_show_rm_import 'data.aws_kms_key.byok' 'REPLACE_ME_byok_key_id_or_arn' "If using BYOK, provide its ARN or key id"

do_show_rm_import 'aws_s3_bucket.logs' 'ewec-prod-logs' "S3 bucket name for logs (confirm name)"
do_show_rm_import 'aws_s3_bucket.static' 'ewec-prod-static' "S3 bucket name for static content (confirm name)"
do_show_rm_import 'aws_s3_bucket_server_side_encryption_configuration.logs' 'ewec-prod-logs' "SSE config for logs bucket"
do_show_rm_import 'aws_s3_bucket_server_side_encryption_configuration.static' 'ewec-prod-static' "SSE config for static bucket"
do_show_rm_import 'aws_s3_bucket_policy.logs' 'ewec-prod-logs' "S3 bucket policy resource id uses bucket name"
do_show_rm_import 'aws_s3_bucket_policy.logs_flowlogs' 'ewec-prod-logs' "Flowlogs policy binding"
do_show_rm_import 'aws_s3_bucket_acl.logs' 'ewec-prod-logs' "ACL resource id is bucket name"
do_show_rm_import 'aws_s3_bucket_ownership_controls.logs' 'ewec-prod-logs' ""
do_show_rm_import 'aws_s3_bucket_public_access_block.ewec_prod_static' 'ewec-prod-static' ""
do_show_rm_import 'aws_s3_bucket_public_access_block.logs' 'ewec-prod-logs' ""

do_show_rm_import 'module.vpc.aws_vpc.this[0]' 'REPLACE_ME_vpc_id' "Find with: aws ec2 describe-vpcs --filters Name=tag:Name,Values=ewec-prod* or by CIDR"
do_show_rm_import 'module.vpc.aws_subnet.private[0]' 'REPLACE_ME_private_subnet_0'
do_show_rm_import 'module.vpc.aws_subnet.private[1]' 'REPLACE_ME_private_subnet_1'
do_show_rm_import 'module.vpc.aws_subnet.public[0]' 'REPLACE_ME_public_subnet_0'
do_show_rm_import 'module.vpc.aws_subnet.public[1]' 'REPLACE_ME_public_subnet_1'
do_show_rm_import 'module.vpc.aws_internet_gateway.this[0]' 'REPLACE_ME_igw_id'

do_show_rm_import 'module.vpc.aws_eip.nat[0]' 'REPLACE_ME_eipalloc_nat_0' "EIP allocation id (aws ec2 describe-addresses)"
do_show_rm_import 'module.vpc.aws_eip.nat[1]' 'REPLACE_ME_eipalloc_nat_1'

do_show_rm_import 'module.vpc.aws_nat_gateway.this[0]' 'REPLACE_ME_nat_0' "NAT id"
do_show_rm_import 'module.vpc.aws_nat_gateway.this[1]' 'REPLACE_ME_nat_1'

do_show_rm_import 'module.vpc.aws_route_table.public[0]' 'REPLACE_ME_rtb_public_0'
do_show_rm_import 'module.vpc.aws_route_table.private[0]' 'REPLACE_ME_rtb_private_0'
do_show_rm_import 'module.vpc.aws_route_table_association.public[0]' 'REPLACE_ME_rtbassoc_public_0'
do_show_rm_import 'module.vpc.aws_route_table_association.private[0]' 'REPLACE_ME_rtbassoc_private_0'
do_show_rm_import 'module.vpc.aws_route_table_association.private[1]' 'REPLACE_ME_rtbassoc_private_1'

do_show_rm_import 'aws_security_group.alb' 'REPLACE_ME_sg_alb'
do_show_rm_import 'aws_security_group.eks_nodes' 'REPLACE_ME_sg_eks_nodes'
do_show_rm_import 'aws_security_group.efs' 'REPLACE_ME_sg_efs'
do_show_rm_import 'aws_security_group.redis' 'REPLACE_ME_sg_redis'

do_show_rm_import 'aws_security_group_rule.eks_nodes_in_dns_tcp' 'REPLACE_ME_rule_id_or_composite' "SG rule import id format depends on resource; consult Terraform docs"

do_show_rm_import 'aws_efs_file_system.this' 'REPLACE_ME_fs_id' "Get with: aws efs describe-file-systems"
do_show_rm_import 'aws_efs_mount_target.mt[\"0\"]' 'REPLACE_ME_mt_id_az_0' "Get with: aws efs describe-mount-targets --file-system-id <fs-id>"
do_show_rm_import 'aws_efs_mount_target.mt[\"1\"]' 'REPLACE_ME_mt_id_az_1'
do_show_rm_import 'aws_efs_access_point.prod' 'REPLACE_ME_efs_ap_prod' "Get with: aws efs describe-access-points --file-system-id <fs-id>"

do_show_rm_import 'module.db.module.db_instance.aws_db_instance.this[0]' 'REPLACE_ME_rds_identifier' "RDS instance identifier (e.g. ewec-prod-mysql)"
do_show_rm_import 'module.db.module.db_instance.aws_cloudwatch_log_group.this[\"error\"]' '/aws/rds/instance/REPLACE_ME_rds_identifier/error'
do_show_rm_import 'module.db.module.db_instance.aws_cloudwatch_log_group.this[\"general\"]' '/aws/rds/instance/REPLACE_ME_rds_identifier/general'
do_show_rm_import 'module.db.module.db_instance.aws_cloudwatch_log_group.this[\"slowquery\"]' '/aws/rds/instance/REPLACE_ME_rds_identifier/slowquery'
do_show_rm_import 'module.db.module.db_instance.aws_cloudwatch_log_group.this[\"audit\"]' '/aws/rds/instance/REPLACE_ME_rds_identifier/audit'

do_show_rm_import 'module.eks.aws_eks_cluster.this[0]' 'REPLACE_ME_eks_cluster_name' "Cluster name from state (e.g. ewec-prod-eks)"
do_show_rm_import 'aws_eks_addon.coredns' 'REPLACE_ME_eks_cluster_name:coredns' "format clusterName:addonName"
do_show_rm_import 'aws_eks_addon.vpc_cni' 'REPLACE_ME_eks_cluster_name:vpc-cni'
do_show_rm_import 'aws_eks_addon.kube_proxy' 'REPLACE_ME_eks_cluster_name:kube-proxy'
do_show_rm_import 'aws_eks_addon.efs_csi' 'REPLACE_ME_eks_cluster_name:aws-efs-csi-driver'

do_show_rm_import 'module.eks.module.eks_managed_node_group["ng-prod"].aws_eks_node_group.this[0]' 'REPLACE_ME_nodegroup_name' "Get with: aws eks list-nodegroups --cluster-name <cluster>"

do_show_rm_import 'module.eks_irsa.aws_iam_role.this[0]' 'REPLACE_ME_irsa_role_arn_or_name' "Get role name/arn from IAM console or aws iam list-roles"
do_show_rm_import 'module.eks_irsa_efs.aws_iam_role.this[0]' 'REPLACE_ME_irsa_efs_role_arn_or_name'

do_show_rm_import 'aws_cloudwatch_log_group.eks_workloads' '/aws/eks/REPLACE_ME_eks_cluster_name/workloads'
do_show_rm_import 'aws_cloudwatch_log_group.eks_app' '/aws/eks/REPLACE_ME_eks_cluster_name/app'
do_show_rm_import 'aws_cloudwatch_log_group.cloudtrail' '/aws/cloudtrail/REPLACE_ME_cloudtrail_name'
do_show_rm_import 'aws_cloudwatch_log_resource_policy.waf_prod' 'AWSWAF-LOGS-Explicit-Prod'

do_show_rm_import 'aws_cloudwatch_metric_alarm.eks_pods_not_ready' 'REPLACE_ME_alarm_name_eks_pods_not_ready'
do_show_rm_import 'aws_cloudwatch_metric_alarm.kms_failed_key_rotation["db"]' 'REPLACE_ME_kms_failed_key_rotation_db'
do_show_rm_import 'aws_cloudwatch_metric_alarm.kms_key_disabled["db"]' 'REPLACE_ME_kms_key_disabled_db'

do_show_rm_import 'aws_elasticache_replication_group.redis' 'REPLACE_ME_elasticache_replication_group_id' "Verify resource exists before import"

do_show_rm_import 'aws_iam_role.backup' 'REPLACE_ME_backup_role_name_or_arn'
do_show_rm_import 'aws_iam_role.fluentbit' 'REPLACE_ME_fluentbit_role_name_or_arn'
do_show_rm_import 'aws_iam_role.gd_s3_malware_role' 'REPLACE_ME_gd_s3_malware_role'
do_show_rm_import 'aws_iam_policy.ct_to_cw' 'REPLACE_ME_ct_to_cw_policy_arn'
do_show_rm_import 'aws_iam_policy.fluentbit_cw_new' 'REPLACE_ME_fluentbit_policy_arn'
do_show_rm_import 'aws_iam_role_policy_attachment.fluentbit_cw_new_attach' 'REPLACE_ME_attach_id_or_name'

do_show_rm_import 'aws_sns_topic.alerts' 'REPLACE_ME_sns_topic_name_or_arn'
do_show_rm_import 'aws_sns_topic_subscription.email' 'REPLACE_ME_sns_subscription_arn' "Subscription ARN (format: arn:aws:sns:...:topic:subscription-id)"

do_show_rm_import 'aws_config_configuration_recorder.this' 'default'
do_show_rm_import 'aws_config_delivery_channel.this' 'default'
do_show_rm_import 'aws_cloudtrail.this' 'REPLACE_ME_cloudtrail_name_or_id' "Get with: aws cloudtrail describe-trails"
do_show_rm_import 'aws_guardduty_detector.this' 'REPLACE_ME_guardduty_detector_id'
do_show_rm_import 'aws_wafv2_web_acl.alb' 'REPLACE_ME_waf_acl_arn_or_name'
do_show_rm_import 'aws_wafv2_web_acl_logging_configuration.prod' 'REPLACE_ME_waf_logging_arn'

do_show_rm_import 'aws_ecr_repository.app' 'REPLACE_ME_ecr_repo_name' "e.g. ewec-prod-app"
do_show_rm_import 'aws_flow_log.vpc' 'REPLACE_ME_flow_log_id'
do_show_rm_import 'aws_backup_vault.this' 'REPLACE_ME_backup_vault_name'
do_show_rm_import 'aws_backup_plan.rds' 'REPLACE_ME_backup_plan_id'

do_show_rm_import 'aws_vpc_endpoint.s3' 'REPLACE_ME_vpc_endpoint_s3' "aws ec2 describe-vpc-endpoints --filters Name=service-name,Values=com.amazonaws.<region>.s3"

echo
echo "${GREEN}All done iterating configured resources.${RESET}"
echo
echo "When finished, run:"
echo "  terraform plan -lock=false -var-file=${VARFILE} -out=tfplan"
echo "  terraform show -no-color tfplan | less"
echo
echo "If you need to restore the previous state, re-upload the ${BACKUP} to your backend (depends on backend)."
echo

