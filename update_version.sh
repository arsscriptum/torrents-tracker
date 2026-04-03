#!/bin/bash

# ┌────────────────────────────────────────────────────────────────────────────────┐
# │                                                                                │
# │   update_version.sh                                                            │
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

log_version() {
    echo -e "${RED}[VERSION] ${NC}"
    echo -e "${YELLOW}$1${NC}\n"
}

log_ok() {
    echo -e "${GREEN}[SUCCESS] $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

ROOT_DIR="/home/services/torrents-tracker"
pushd $ROOT_DIR


VERSION_FILE=$ROOT_DIR/version.nfo
BUILD_FILE=$ROOT_DIR/build.nfo

# Get current version from version.nfo (assuming the format is major.minor.build)
current_version=$(cat "$VERSION_FILE")
IFS='.' read -r major minor build <<< "$current_version"

# Increment build number
build=$((build + 1))
new_version="$major.$minor.$build"

# Write the new version back to the version.nfo file
echo "$new_version" > "$VERSION_FILE"

# Get Git info
current_branch=$(git branch --show-current)
head_rev=$(git log --format=%h -1)
last_rev=$(git log --format=%h -2 | tail -n 1)

# Write the Git branch and revision information to build.nfo
{
    echo "$current_branch"
    echo "$head_rev"
} > "$BUILD_FILE"


log_version "Version updated to $new_version"
log_version "Branch and revision info saved to $BUILD_FILE"
popd
