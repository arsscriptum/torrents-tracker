#!/bin/bash

#+--------------------------------------------------------------------------------+
#|                                                                                |
#|   run.sh                                                                       |
#|                                                                                |
#+--------------------------------------------------------------------------------+
#|   Guillaume Plante <codegp@icloud.com>                                         |
#|   Code licensed under the GNU GPL v3.0. See the LICENSE file for details.      |
#+--------------------------------------------------------------------------------+

# variables for colors
WHITE='\033[0;30m'
MAGENTA='\033[0;35m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color
GREEN='\033[0;32m'

# variables for cmd arguments
ASYNC_OPT=1
STOP_OPT=0
DEBUG_OPT=0
RUN_OPT=0
INCREMENTAL_OPT=0

UPDATE_VERSION_OPT=0
DEPLOYIMAGE_OPT=0
GETVERSION_OPT=0

SCRIPT_PATH=$(realpath "$BASH_SOURCE")
SCRIPT_DIR=$(dirname "$SCRIPT_PATH")

tmp_root=$(pushd "$SCRIPT_DIR/.." | awk '{print $1}')
ROOT_DIR=$(eval echo "$tmp_root")
ENV_FILE="$ROOT_DIR/.env"
ROOT_DIRECTORY="$ROOT_DIR"
SCRIPT_DIR="$ROOT_DIR/scripts"
LOGS_DIR="$ROOT_DIR/logs"
LOG_FILE="$LOGS_DIR/run.log"
VERSION_FILE=$ROOT_DIR/version.nfo
BUILD_FILE=$ROOT_DIR/build.nfo

MONITOR_LOOP_STATUS_FILE="/tmp/monitor_loop.txt"
COMPFILE_PATH=$ROOT_DIR/docker-compose.yml
COMPFILE_DEVELOPMENT=$ROOT_DIR/yaml/docker-compose_standalone.yml
COMPFILE_PRODUCTION=$ROOT_DIR/yaml/docker-compose_full.yml

LOGGING="$SCRIPT_DIR/logging.sh"
STATUS_FUNCS="$SCRIPT_DIR/status-funcs.sh"
VERSION_SCRIPT=$SCRIPT_DIR/update_version.sh


if [[ -f "$ENV_FILE" ]]; then
   source "$ENV_FILE"
else
   echo "[error] missing .env file @ \"$ENV_FILE\"!"
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



# Usage function
usage() {
    echo "Usage: $0 [options]"  
    echo "  -a, --async             Runs the containers in the background (detached mode)"
    echo "  -d, --debug             DEBUG MODE (no VPN)"
    echo "  -h, --help              Show this help message"
    exit 0
}

log_info() {
    if [[ -f "$LOG_FILE" ]]; then
        echo "[$(date)] $1" >> "$LOG_FILE"
    fi
    echo -e "${BLUE}[log]${NC} $1"
}
log_warn() {
    if [[ -f "$LOG_FILE" ]]; then
        echo "[$(date)] $1" >> "$LOG_FILE"
    fi
    echo -e "${MAGENTA}[warn]${NC} ${WHITE}$1${NC}"
}
log_error() {
    if [[ -f "$LOG_FILE" ]]; then
        echo "[$(date)] $1" >> "$LOG_FILE"
    fi
    echo -e "${RED}[error]${NC} ${YELLOW}$1${NC}"
    exit 1
}

get_next_filename() {
    local base_file="$1"
    local max_suffix=9
    local next_file=""

    for i in $(seq 0 $max_suffix); do
        next_file="${base_file}.${i}"
        if [[ ! -e "$next_file" ]]; then
            echo "$next_file"
            return
        fi
    done

    next_file="${base_file}.0"
    rm -rf $next_file
    echo "$next_file"
    return
}

BUILD_START_TIME=$(date +"%Y-%m-%d %H:%M:%S")

if [[ ! -d "$LOGS_DIR" ]]; then
   mkdir -p "$LOGS_DIR"
   chmod -R 777 "$LOGS_DIR"
   log_info "Creating \"$LOGS_DIR\""
fi


if [[ -f "$LOG_FILE" ]]; then
    next_file=$(get_next_filename "$LOG_FILE")
    log_info "Next available filename: $next_file"
    log_info "Backup of log file \"$next_file\""
    mv -f "$LOG_FILE" "$next_file"
fi

echo -e  "\n\n ========== BUILD STARTED ON $BUILD_START_TIME ========== \n" > "$LOG_FILE"

# Set the log level (e.g., DEBUG, INFO, WARNING, ERROR, CRITICAL).
LOG_LEVEL="WARNING"

while [[ $# -gt 0 ]]; do
    case "$1" in
        -a|--async)
            ASYNC_OPT=1
            ;;
        -s|--stop)
            STOP_OPT=1
            ;;
        -d|--debug)
            LOG_LEVEL="DEBUG"
            DEBUG_OPT=1
            set -x
            ;;
        -h|--help)
            usage
            ;;
    esac
    shift # Move to the next argument
done


DETACH_MODE=""

if [[ "$ASYNC_OPT" -eq 1 ]]; then
    DETACH_MODE="-d"
fi


LOG_FILE="$LOGS_DIR/run.log"
BUILD_RUN_TIME=$(date +"%Y-%m-%d %H:%M:%S")
echo -e  "\n\n ========== SERVICE RUN STARTED ON $BUILD_RUN_TIME ========== \n" > "$LOG_FILE"


update_log_file "$LOG_FILE"

if [[ "$STOP_OPT" -eq 1 ]]; then
     log_info "Stopping torrents-tracker service"
     echo "0" > "$MONITOR_LOOP_STATUS_FILE"
     sleep 4
     docker-compose --file "$COMPFILE_PATH" down
else
    update_run_time "start"
    
    if [[ "$ASYNC_OPT" -eq 1 ]]; then
        docker-compose --file "$COMPFILE_PATH" up --detach --remove-orphans
        update_current_state "active"
    else
        log_info "Running torrents-tracker service"
        update_current_state "active"
        docker-compose --file "$COMPFILE_PATH" up --remove-orphans
        exit 0
    fi
fi


monitor_loop() {
  # Ensure the control file exists
  if [[ ! -f "$MONITOR_LOOP_STATUS_FILE" ]]; then
      echo "1" > "$MONITOR_LOOP_STATUS_FILE"
  fi

  echo "1" > "$MONITOR_LOOP_STATUS_FILE"
  SHOULD_RUN=$(cat "$MONITOR_LOOP_STATUS_FILE")
  while [[ $SHOULD_RUN -eq 1 ]]; do
      
      # Perform the health check
      do_health_check false
      
      # Wait before the next iteration
      sleep 5
      SHOULD_RUN=$(cat "$MONITOR_LOOP_STATUS_FILE")
  done

  log_info "[monitor_loop] exiting loop"
}


if [[ "$ASYNC_OPT" -eq 1 ]]; then
    monitor_loop
fi



exit 0