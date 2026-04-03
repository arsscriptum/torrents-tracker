#!/bin/bash

SCRIPT_PATH=$(realpath "$BASH_SOURCE")
SCRIPT_DIR=$(dirname "$SCRIPT_PATH")

ROOT_DIR=$(pushd "$SCRIPT_DIR/.." | awk '{print $1}')
ENV_FILE="$ROOT_DIR/.env"

pushd "$ROOT_DIR"

STATUS_FUNCS="$SCRIPT_DIR/status-funcs.sh"

if [[ -f "$ENV_FILE" ]]; then
   source "$ENV_FILE"
else
   echo "[error] missing .env file!"
   exit 1
fi

if [[ -f "$LOGGING" ]]; then
   source "$LOGGING"
else
   LOGGING="$SCRIPT_PATH/logging.sh"
   source "$LOGGING"
fi

if [[ -f "$STATUS_FUNCS" ]]; then
   source "$STATUS_FUNCS"
else
   echo "[error] missing status functions file!"
   exit 3
fi


# variables for cmd arguments
CLEAN_OPT=0
DRYRUN_OPT=0
INCREMENTAL_OPT=0

# Usage function
usage() {
    echo "Usage: $0 [options]"  
    echo "  -c, --clean        clean build : no cache"
    echo "  -d, --dryrun       do nothing, just test, logs"
    echo "  -i, --incremental  smaller build"
    echo "  -h, --help         Show this help message"
    exit 0
}


# Parse script arguments
for arg in "$@"; do
    case $arg in
        -c|--clean)
            CLEAN_OPT=1
            ;;
        -i|--incremental)
            INCREMENTAL_OPT=1
            ;;
        -d|--dryrun)
            DRYRUN_OPT=1
            ;;
        -h|--help)
            usage
            ;;
    esac
done


NO_CACHE_CMD=""
if [[ "$CLEAN_OPT" -eq 1 ]]; then
  NO_CACHE_CMD="--no-cache"
fi

update_current_state "down"

COMPFILE_PATH=$ROOT_DIR/docker-compose.yml
COMPFILE_PRODUCTION=$ROOT_DIR/yaml/docker-compose_full.yml

log_info "Updating docker-compose file..."

log_info "You selected the production environment: using VPN"
cp --verbose --force $COMPFILE_PRODUCTION $COMPFILE_PATH

BUILD_START_TIME=$(date +"%Y-%m-%d %H:%M:%S")

update_build_time start 
update_current_state "building"

log_info "$BUILD_START_TIME Started building torrents-tracker containers"

if [[ "$DRYRUN_OPT" -eq 1 ]]; then
  log_test "waiting 15 seconds, simulating docker building containers..."
  sleep 15
  log_info "[simulating building containers]"
  RESULT=0
else
  log_info "running \"docker-compose -f \"$ROOT_DIR/docker-compose.yml\" build $NO_CACHE_CMD\""
  log_info "[building containers]"
  docker-compose -f "$ROOT_DIR/docker-compose.yml" build "$NO_CACHE_CMD"
  RESULT=$?
fi 

popd

update_build_time end

# Check if the build was successful
if [ $RESULT -eq 0 ]; then
  log_ok "Docker Compose project built successfully."
  update_current_state "build-ready"
  exit 0
else
  log_warning "Failed to build the Docker Compose project."
  update_current_state "build-failed"
  exit 1
fi


