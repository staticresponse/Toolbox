#!/usr/bin/env bash
set -euo pipefail

#######################################
# Configuration
#######################################
AWS_REGION="us-east-1"
AWS_ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
ECR_REPO="my-ecr-repo"
IMAGE_TAG="latest"

LOCAL_IMAGE=""
SNS_TOPIC_ARN=""

WORK_DIR="/opt/ops"
REPORT_FILE="$WORK_DIR/ecr_push_report.txt"
DATE_FMT="+%Y-%m-%d %H:%M:%S"

#######################################
# Functions
#######################################
log() {
  echo "[$(date "$DATE_FMT")] $*"
}

write_report() {
  echo "$*" >> "$REPORT_FILE"
}

require_binary() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "ERROR: Required binary not found: $1"
    exit 1
  }
}

ecr_login() {
  log "Authenticating to ECR"
  aws ecr get-login-password --region "$AWS_REGION" \
    | docker login --username AWS --password-stdin \
      "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"
}

ensure_repo_exists() {
  if ! aws ecr describe-repositories \
      --repository-names "$ECR_REPO" \
      --region "$AWS_REGION" >/dev/null 2>&1; then

    log "Creating ECR repository: $ECR_REPO"
    aws ecr create-repository \
      --repository-name "$ECR_REPO" \
      --region "$AWS_REGION" \
      >/dev/null
  fi
}

tag_image() {
  local target_image="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO:$IMAGE_TAG"

  log "Tagging image"
  docker tag "$LOCAL_IMAGE" "$target_image"
  echo "$target_image"
}

push_image() {
  local image="$1"

  log "Pushing image to ECR"
  docker push "$image"
}

send_notification() {
  if [[ -z "$SNS_TOPIC_ARN" ]]; then
    log "SNS not configured — skipping notification"
    return
  fi

  log "Sending SNS notification"
  aws sns publish \
    --region "$AWS_REGION" \
    --topic-arn "$SNS_TOPIC_ARN" \
    --message "file://$REPORT_FILE" \
    --subject "ECR Image Push Report"
}

#######################################
# Main
#######################################
require_binary aws
require_binary docker

if [[ -z "$LOCAL_IMAGE" ]]; then
  echo "ERROR: LOCAL_IMAGE must be set (e.g. myapp:latest)"
  exit 1
fi

mkdir -p "$WORK_DIR"
: > "$REPORT_FILE"

write_report "ECR Image Push Report"
write_report "Host: $(hostname)"
write_report "Date: $(date)"
write_report "----------------------------------"
write_report "Local Image: $LOCAL_IMAGE"
write_report "Repository: $ECR_REPO"
write_report "Tag: $IMAGE_TAG"
write_report ""

ecr_login
ensure_repo_exists

ECR_IMAGE="$(tag_image)"
push_image "$ECR_IMAGE"

write_report "Push completed successfully"
write_report "ECR Image URI:"
write_report "  $ECR_IMAGE"

send_notification

log "Done"
