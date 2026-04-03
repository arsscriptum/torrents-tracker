#!/bin/bash

# ┌────────────────────────────────────────────────────────────────────────────────┐
# │                                                                                │
# │   restart.sh                                                                   │
# │                                                                                │
# ┼────────────────────────────────────────────────────────────────────────────────┼
# │   Guillaume Plante  <guillaumeplante.qc@gmail.com>                             │
# └────────────────────────────────────────────────────────────────────────────────┘

# Check if the script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Error: This script must be run as root." >&2
  exit 1
fi


# Colors for output
UL='\033[4;93m'
IL='\033[3;91m'
BL='\033[6;94m'
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

LogCategory=torrtracker

# handy logging and error handling functions
pecho() { printf %s\\n "$*"; }

log() { pecho "$@"; }

# Verbose output function
log_info() {
    echo -e "${CYAN}[INFO] $1${NC}"
    logger --tag $LogCategory -p user.info "[INFO] $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
    logger --tag $LogCategory -p user.warning "[WARNING] $1"
}


log_info" Restart the torrents-tracker service"
sudo systemctl restart torrents-tracker.service

# Check if the service restarted successfully
if systemctl is-active --quiet torrents-tracker.service; then
    log_info "torrents-tracker.service restarted successfully."
else
    log_warning "Failed to restart torrents-tracker.service."
fi
