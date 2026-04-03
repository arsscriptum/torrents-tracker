#!/bin/bash

# ┌────────────────────────────────────────────────────────────────────────────────┐
# │                                                                                │
# │   start.sh                                                                     │
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
log_title() {
    echo -e "${IL}$1${NC}"
    logger --tag $LogCategory -p user.info "$1"
}

# Verbose output function
log_info() {
    echo -e "${CYAN}[INFO] $1${NC}"
    logger --tag $LogCategory -p user.info "[INFO] $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
    logger --tag $LogCategory -p user.warning "[WARNING] $1"
}

log_title "COLLECT AND TEST"


LOG_DIR=/srv/logs/torrents-tracker

# Get the directory of the script and the root directory
SCRIPT_DIR=$(dirname "${BASH_SOURCE[0]}")
pushd $SCRIPT_DIR/..
ROOT_DIR=`pwd`
TEMPLATE_DOCKERFILE=$ROOT_DIR/yaml/Dockerfile.Backup.Collect
PROJECT_DOCKERFILE=$ROOT_DIR/Dockerfile
log_warning "copying $TEMPLATE_DOCKERFILE to $PROJECT_DOCKERFILE"
cp -vf $TEMPLATE_DOCKERFILE $PROJECT_DOCKERFILE

COMMAND=`cat $PROJECT_DOCKERFILE | tail -n 1`
log_warning "DOCKER BUILD RUNNING COMMAND"
log_warning "$COMMAND"

docker build -t django-app .

docker run -p 7070:7070 django-app

popd


