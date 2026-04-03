#!/bin/bash

# ┌────────────────────────────────────────────────────────────────────────────────┐
# │                                                                                │
# │   git-save.sh                                                                  │
# │                                                                                │
# ┼────────────────────────────────────────────────────────────────────────────────┼
# │   Guillaume Plante  <guillaumeplante.qc@gmail.com>                             │
# └────────────────────────────────────────────────────────────────────────────────┘

# Colors for output
UL='\033[4;93m'
IL='\033[3;91m'
BL='\033[6;94m'
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

LogCategory=torrtracker

# handy logging and error handling functions
pecho() { printf %s\\n "$*"; }

log() { pecho "$@"; }


log_file() {
    echo -e "${YELLOW}$1${NC}"
    logger --tag $LogCategory -p user.warning "$1"
}

# Verbose output function
log_title() {
    echo -e "${IL}$1${NC}"
    logger --tag $LogCategory -p user.info "$1"
}

log_error() {
    echo -e "${RED}[ERROR] $1${NC}"
    logger --tag $LogCategory -p user.error "[ERROR] $1"
}

log_success() {
    echo -e "${GREEN}[OK] $1${NC}"
    logger --tag $LogCategory -p user.info "[OK] $1"
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

# Define the root directory
ROOT_DIR="$HOME/dev/torrents-tracker"

# Check if the current directory is within ~/dev/torrents-tracker or a child directory
if [[ "$(pwd)" != "$ROOT_DIR"* ]]; then
    echo "Error: This script must be run from $ROOT_DIR or one of its subdirectories."
    exit 1
fi

# Get the directory of the script and the root directory
SCRIPT_DIR=$(dirname "${BASH_SOURCE[0]}")

pushd $ROOT_DIR > /dev/null

# Initialize arrays for different statuses
ModifiedFiles=()
AddedFiles=()
DeletedFiles=()
UntrackedFiles=()

# Parse 'git status --short' output
while read -r status file; do
    case "$status" in
        M*) ModifiedFiles+=("$file") ;;
        A*) AddedFiles+=("$file") ;;
        D*) DeletedFiles+=("$file") ;;
        \?\?) UntrackedFiles+=("$file") ;;
    esac
done < <(git status --short)


# Count files in each array
ModifiedCount=${#ModifiedFiles[@]}
AddedCount=${#AddedFiles[@]}
DeletedCount=${#DeletedFiles[@]}
UntrackedCount=${#UntrackedFiles[@]}
CommitCount=0
# Display results


if [[ $ModifiedCount -gt 0 ]]; then
    CommitCount+=$ModifiedCount
    git add "${ModifiedFiles[@]}"
fi


if [[ $AddedCount -gt 0 ]]; then
    CommitCount+=$AddedFiles
    git add "${AddedFiles[@]}"
fi


if [[ $DeletedCount -gt 0 ]]; then
    CommitCount+=$DeletedFiles
    git add "${DeletedFiles[@]}"
fi


if [[ $UntrackedCount -gt 0 ]]; then
    git add "${UntrackedFiles[@]}"
fi


# Use the argument as the commit message or default to "auto commit"
CommitMessage=${1:-"auto commit"}

if [[ $CommitCount -gt 0 ]]; then
    # Commit the changes
    log_file "Committing changes with message: '$CommitMessage' . $CommitCount files"
    git commit -m "$CommitMessage" > /dev/null   2>&1 
    if [[ $? -eq 0 ]]; then
        log_success "Changes committed successfully."
    else
        log_error "Commit failed."
        exit 1
    fi
    git push > /dev/null 2>&1 
else 
    log_success "Everything up to date!"
fi


popd > /dev/null


