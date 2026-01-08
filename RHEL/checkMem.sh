#!/usr/bin/env bash
set -euo pipefail

#######################################
# Configuration
#######################################
LOG_FILE="/var/log/mem.log"
DATE_FMT="+%Y-%m-%d %H:%M:%S"

#######################################
# Functions
#######################################
log() {
  echo "[$(date "$DATE_FMT")] $*" >> "$LOG_FILE"
}

calculate_free_memory_percent() {
  awk '
    /MemTotal:/ { total = $2 }
    /MemFree:/  { free  = $2 }
    END {
      if (total > 0) {
        printf "%.3f\n", (free * 100) / total
      } else {
        print "0.000"
      }
    }
  ' /proc/meminfo
}

#######################################
# Main
#######################################
: > "$LOG_FILE"

free_percent=$(calculate_free_memory_percent)
log "Free memory: ${free_percent}%"
