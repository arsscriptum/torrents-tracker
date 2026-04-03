#!/bin/bash

#+--------------------------------------------------------------------------------+
#|                                                                                |
#|   utils.sh                                                                     |
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
ASYNC_OPT=0
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


show_tracker_logs() {
     timestamp=$(cat /home/services/torrents-tracker/state.json | jq .build.started_on)
     journalctl --since="@$timestamp" -u torrents-tracker
}

show_tracker_status() {
     /home/services/torrents-tracker/scripts/check_ip.sh
     cat /home/services/torrents-tracker/state.json
}


check_tracker_access() {
  local retval=0
  curl -s "http://10.0.0.111:7070/tracker/" | grep -q "/tracker/searchTorrents"
  if [ $? -ne 0 ]; then
    retval=1
    echo "[access] cannot acces torrents-tracker"
  fi

  log_ok "[access] ok!"
}

# Function to check activity status
check_tracker_activity_status() {
    local retval=0
    local activity_status="inactive"
    #local activity_status=$(systemctl is-active torrents-tracker.service)
    if docker ps | grep -q "torrents-tracker:latest"; then
        activity_status="active"
        log_ok "[activity] torrents-tracker is running and active"
    else
        retval=1
        log_warning "[activity] torrents-tracker failed to start."
    fi    
}
