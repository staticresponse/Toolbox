#!/usr/bin/env bash
set -euo pipefail

#######################################
# Configuration
#######################################
ACCOUNT_LIST="/data/admin/accountlist.txt"
OUTPUT_FILE="/data/admin/accountreport.txt"

SNS_TOPIC_ARN=""
SNS_REGION=""

DATE_FMT="+%Y-%m-%d %H:%M:%S"

#######################################
# Functions
#######################################
log() {
  echo "[$(date "$DATE_FMT")] $*"
}

collect_password_expirations() {
  log "Generating password expiration report"

  {
    echo "Password Expiration Report"
    echo "Generated: $(date)"
    echo "----------------------------------"
  } > "$OUTPUT_FILE"

  while IFS= read -r user; do
    [[ -z "$user" || "$user" =~ ^# ]] && continue

    if ! chage_output=$(chage -l "$user" 2>/dev/null); then
      printf "%-20s %s\n" "$user" "ERROR: user not found" >> "$OUTPUT_FILE"
      continue
    fi

    expires=$(echo "$chage_output" \
      | awk -F: '/Password expires/ {print $2}' \
      | xargs)

    printf "%-20s %s\n" "$user" "$expires" >> "$OUTPUT_FILE"
  done < "$ACCOUNT_LIST"
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
    --subject "Password Expiration Report"
}

#######################################
# Main
#######################################
collect_password_expirations
send_sns_notification

log "Done"
