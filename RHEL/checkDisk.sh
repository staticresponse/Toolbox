#!/usr/bin/env bash
set -euo pipefail

#######################################
# Configuration
#######################################
SNS_TOPIC_ARN=""
SNS_REGION=""

OUTPUT_FILE="/data/admin/diskFull.txt"
DATE_FMT="+%Y-%m-%d %H:%M:%S"

#######################################
# Functions
#######################################
log() {
  echo "[$(date "$DATE_FMT")] $*"
}

collect_disk_usage() {
  log "Collecting disk usage"

  {
    echo "Disk Space Report"
    echo "Generated: $(date)"
    echo "----------------------------------"

    df -H --output=pcent,source \
      | tail -n +2 \
      | while read -r usep partition; do
          usep="${usep%\%}"
          printf "%-25s %s%%\n" "$partition" "$usep"
        done
  } > "$OUTPUT_FILE"
}

send_sns_notification() {
  if [[ -z "$SNS_TOPIC_ARN" || -z "$SNS_REGION" ]]; then
    log "SNS not configured — skipping notification"
    return
  fi

  log "Sending SNS notification"
  aws sns publish \
    --region "$SNS_REGION" \
    --topic-arn "$SNS_TOPIC_ARN" \
    --message "file://$OUTPUT_FILE" \
    --subject "Disk Space Notification"
}

#######################################
# Main
#######################################
collect_disk_usage
send_sns_notification

log "Done"
