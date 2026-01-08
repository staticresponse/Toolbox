#!/usr/bin/env bash
set -euo pipefail

#######################################
# Configuration
#######################################
SNS_TOPIC_ARN="<your sns topic arn>"
SNS_REGION="<your aws region>"

WORK_DIR="/opt/ops"
PATCH_REPORT="$WORK_DIR/patch.txt"
UPDATE_LOG="$WORK_DIR/updateLog.txt"

AWS="/usr/local/aws/bin/aws"
HOSTNAME="$(hostname)"
DATE_FMT="+%Y-%m-%d %H:%M:%S"

#######################################
# Functions
#######################################
log() {
  echo "[$(date "$DATE_FMT")] $*"
}

write_report() {
  echo "$*" >> "$PATCH_REPORT"
}

get_instance_id() {
  curl -s http://169.254.169.254/latest/meta-data/instance-id
}

snapshot_volumes() {
  local instance_id="$1"

  log "Creating EBS snapshots for instance $instance_id"
  write_report "Snapshot activity:"

  mapfile -t volumes < <(
    "$AWS" ec2 describe-volumes \
      --filters Name=attachment.instance-id,Values="$instance_id" \
      --query 'Volumes[].VolumeId' \
      --output text
  )

  for vol in "${volumes[@]}"; do
    log "Snapshotting volume $vol"
    "$AWS" ec2 create-snapshot \
      --volume-id "$vol" \
      --description "$HOSTNAME pre-patch snapshot $(date +%F)" \
      >/dev/null

    write_report "  - Snapshot requested for $vol"
  done
}

apply_patches() {
  log "Running yum update"
  yum update -y --exclude awscli > "$UPDATE_LOG" 2>&1

  write_report ""
  write_report "Patch Results:"
  grep -i "Packages" "$UPDATE_LOG" >> "$PATCH_REPORT" || true
  grep -i "failed"   "$UPDATE_LOG" >> "$PATCH_REPORT" || true
}

send_notification() {
  if [[ -z "$SNS_TOPIC_ARN" || -z "$SNS_REGION" ]]; then
    log "SNS not configured — skipping notification"
    return
  fi

  log "Sending SNS notification"
  "$AWS" sns publish \
    --region "$SNS_REGION" \
    --topic-arn "$SNS_TOPIC_ARN" \
    --message "file://$PATCH_REPORT" \
    --subject "Patch Activity Report - $HOSTNAME"
}

#######################################
# Main
#######################################
mkdir -p "$WORK_DIR"
: > "$PATCH_REPORT"

write_report "Patch Activity Report"
write_report "Host: $HOSTNAME"
write_report "Started: $(date)"
write_report "----------------------------------"

INSTANCE_ID="$(get_instance_id)"
snapshot_volumes "$INSTANCE_ID"

log "Waiting 30 minutes for snapshots to stabilize"
sleep 30m

apply_patches
send_notification

if [[ "${1:-}" == "auto" ]]; then
  log "Auto-reboot requested"
  write_report ""
  write_report "System reboot initiated"
  reboot
fi

log "Patch process complete"
