#!/usr/bin/env bash
set -euo pipefail

LOG_FILE="/var/log/docker_stats.log"

docker stats --no-stream \
  --format "{{.Name}},{{.CPUPerc}},{{.MemUsage}},{{.NetIO}},{{.BlockIO}}" \
  >> "$LOG_FILE"
