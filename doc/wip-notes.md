if systemctl is-active --quiet torrents-tracker.service; then
  echo "Service is running."
else
  echo "Service failed to start."
fi


sudo systemctl start torrents-tracker.service && sudo systemctl is-active torrents-tracker.service


sudo journalctl -u torrents-tracker.service -n 20


sudo systemctl status torrents-tracker.service


sudo systemctl start torrents-tracker.service
if [[ $? -eq 0 ]]; then
  echo "Service started successfully."
else
  echo "Failed to start the service."
fi


systemctl list-units --type=service | grep torrents-tracker



sudo journalctl -u torrents-tracker.service -f



Below is the update JSON file. I need a bash function "get_health_intervals" that will get the health intervals (in seconds). one to know if is_healthy is true: get_is_healthy 

Also, I need a bash function "should_check_health" that will check the last health check time by reading "health" / "tested_on", get the current time, make a difference between the 2, and if it is greater than intervals, return true


{
  "current_state": "stopped",
  "log_path": "$LOGS_DIR/torrentctl.log",
  "started_on": 0,
  "ended_on": 0,
  "health": {
    "tested_on": 0,
    "intervals": 0,
    "is_healthy": 0
  },
  "build": {
    "started_on": 0,
    "ended_on": 0,
    "build_result": 0
  }
}


╔═════════════════════════════════════════════════════════╗
║ json schema              old value      new value       ║






#!/bin/bash

SCRIPT_PATH=$(realpath "$BASH_SOURCE")
SCRIPT_DIR=$(dirname "$SCRIPT_PATH")

ROOT_DIR=$(pushd "$SCRIPT_DIR/.." | awk '{print $1}')
ENV_FILE="$ROOT_DIR/.env"

if [[ -f "$ENV_FILE" ]]; then
   source "$ENV_FILE"
else 
   echo "[error] missing .env file!"
   exit 1
fi

if [[ -f "$LOGGING" ]]; then
   source "$LOGGING"
else
   echo "[error] missing logging file!"
   exit 2
fi


#!/bin/bash

write_torrent_root() {
    local output_file="$1"          # First argument: file to write to
    local torrentsctl_root_dir="$2" # Second argument: value for TORRENTSCTL_ROOT_DIR

    # Validate input
    if [[ -z "$output_file" || -z "$torrentsctl_root_dir" ]]; then
        echo "Usage: write_torrent_root <output_file> <TORRENTSCTL_ROOT_DIR>"
        return 1
    fi

    # Write to the file
    echo "TORRENT_ROOT=\"$torrentsctl_root_dir\"" > "$output_file"

    # Confirm action
    echo "File '$output_file' has been updated with:"
    echo "TORRENT_ROOT=\"$torrentsctl_root_dir\""
}

# Example usage
write_torrent_root "torrent_root.conf" "/home/services/torrents-tracker"










TORRENT_ROOT="$TORRENTSCTL_ROOT_DIR"
LOGGING="$TORRENT_ROOT/scripts/logging.sh"
STATUS_DIR="$TORRENT_ROOT/state"
STATUS_JSON="$STATUS_DIR/health.json"


docker-compose build --no-cache --pull


docker-compose up --remove-orphans







LogCategory=move_media

# Source the logging functions

if [ ! -d "$LOGGING" ]; then
    source /srv/scripts/logging.sh
else
    source $LOGGING
fi

log_info "MOVE MEDIA STARTED"



#!/bin/bash

# Path to the JSON file
JSON_FILE="state.json"

# Function to get health intervals
get_health_intervals() {
    jq -r '.health.intervals' "$JSON_FILE"
}

# Function to check if the system is healthy
get_is_healthy() {
    jq -r '.health.is_healthy' "$JSON_FILE"
}

# Function to check if a health check should be performed
should_check_health() {
    # Get the last health check time and interval
    local last_tested=$(jq -r '.health.tested_on' "$JSON_FILE")
    local interval=$(jq -r '.health.intervals' "$JSON_FILE")

    # Get the current time
    local current_time=$(date +%s)

    # Calculate the time difference
    local time_difference=$((current_time - last_tested))

    # Check if the time difference is greater than the interval
    if ((time_difference > interval)); then
        return 0  # True
    else
        return 1  # False
    fi
}

# Example usage:

# Get the health intervals
echo "Health Intervals: $(get_health_intervals)"

# Check if the system is healthy
if [[ $(get_is_healthy) -eq 1 ]]; then
    echo "The system is healthy."
else
    echo "The system is not healthy."
fi

# Check if a health check should be performed
if should_check_health; then
    echo "A health check should be performed."
else
    echo "No need for a health check."
fi


"ended_on": 0,
  "health": {
    "tested_on": 0,
    "intervals": 0,
    "is_healthy": 0
  },
  "build": {
    "started_on": 0,
    "ended_on": 0,
    "build_result": 0
  }
}