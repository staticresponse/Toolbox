#!/usr/bin/env bash
set -euo pipefail

#######################################
# Configuration
#######################################
THERMAL_ZONE="/sys/class/thermal/thermal_zone0/temp"
LOG_FILE="/var/log/piTemp.log"
DATE_FMT="+%Y-%m-%d %H:%M:%S"

#######################################
# Functions
#######################################
log() {
  echo "[$(date "$DATE_FMT")] $*" >> "$LOG_FILE"
}

read_temperature_fahrenheit() {
  awk '
    {
      celsius = $1 / 1000
      fahrenheit = (celsius * 9 / 5) + 32
      printf "%.3f\n", fahrenheit
    }
  ' "$THERMAL_ZONE"
}

#######################################
# Main
#######################################
: > "$LOG_FILE"

temp_f=$(read_temperature_fahrenheit)
log "CPU Temperature: ${temp_f}°F"
