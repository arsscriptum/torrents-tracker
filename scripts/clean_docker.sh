#!/bin/bash

# ┌────────────────────────────────────────────────────────────────────────────────┐
# │                                                                                │
# │   clean_docker.sh                                                              │
# │                                                                                │
# └────────────────────────────────────────────────────────────────────────────────┘



YELLOW='\033[0;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color




# Handy logging and error handling functions
pecho() { printf %s\\n "$*"; }

log() { pecho "$@"; }

# Verbose output function
log_info() {
    echo -e "${CYAN}[BUILD] $1${NC}"
}

log_ok() {
    echo -e "${GREEN}[SUCCESS] $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}


log "Address the Build Cache"
docker builder prune

log "Remove Unused Images"
docker image prune -a -f

log "To remove all stopped containers"
docker container prune -f

log "General Cleanup"
docker system prune -a --volumes -f

log "Post-Cleanup Check"
docker system df
