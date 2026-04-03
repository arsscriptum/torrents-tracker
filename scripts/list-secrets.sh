#!/bin/bash

# ┌────────────────────────────────────────────────────────────────────────────────┐
# │                                                                                │
# │   list-secrets.sh                                                              │
# │                                                                                │
# └────────────────────────────────────────────────────────────────────────────────┘

YELLOW='\033[0;33m'
YELLOWH='\033[0;93m'
RED='\033[0;31m'
REDH='\033[0;91m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color


# Handy logging and error handling functions
pecho() { printf %s\\n "$*"; }

log() { pecho "$@"; }

DEBUG_MODE=false
# Verbose output function
log_debug() {
    if $DEBUG_MODE; then
        echo -e "${RED}[debug]${NC}${YELLOW} $1${NC}"
    fi
}

log_info() {
    echo -e "${CYAN}[LOG]${NC} $1"
}

log_ok() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1${NC}"
}

log_error() {
    echo -e "${REDH}[ERROR]${NC}${YELLOWH} $1${NC}"; exit 1
}

pushd "$(dirname "$0")/.." > /dev/null
ROOT_DIR=`pwd`

SCRIPTS_DIR="$ROOT_DIR/scripts"

ENV_FILE="$ROOT_DIR/.env"

# Load environment variables from .env file
if [[ -f "$ENV_FILE" ]]; then
    log_debug "Load environment variables from .env file"
    # Use `envsubst` for proper substitution and handling of special characters
    set -a
    source .env
    set +a
else
    log_error "Error: .env file not found. Please create one with GHTOKENWIDE, OWNER, and REPONAME."
    exit 1
fi

REPONAME="torrents-tracker"
OWNER="arsscriptum"
# Validate required variables
if [[ -z "$GHTOKENWIDE" || -z "$OWNER" || -z "$REPONAME" ]]; then
    log_error "Error: GHTOKENWIDE, OWNER, and REPONAME must be set in the .env file."
    exit 1
fi


log_debug "GitHub API Endpoint \"$REQUESTURL\""
log_debug "OWNER \"$OWNER\""
log_debug "REPONAME \"$REPONAME\""
log_debug "COMMIT_SHA \"$COMMIT_SHA\""
log_debug "GitHub API Endpoint \"$REQUESTURL\""


# GitHub API URL for listing repository secrets
API_URL="https://api.github.com/repos/$OWNER/$REPONAME/actions/secrets"

# Fetch and list secrets
response=$(curl -s -H "Authorization: Bearer $GHTOKENWIDE" \
                  -H "Accept: application/vnd.github.v3+json" \
                  "$API_URL")

# Check for errors
if echo "$response" | grep -q '"message":'; then
  echo "Error fetching secrets:"
  echo "$response" | jq
  exit 1
fi

echo -e "reading...\n"
# Parse and display secrets
echo "Secrets for repository '$OWNER/$REPONAME':"
echo "$response" | jq

popd > /dev/null
