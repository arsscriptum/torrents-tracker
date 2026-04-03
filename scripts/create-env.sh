#!/bin/bash

SCRIPT_PATH=$(realpath "$BASH_SOURCE")
SCRIPT_DIR=$(dirname "$SCRIPT_PATH")

tmp_root=$(pushd "$SCRIPT_DIR/.." | awk '{print $1}')
ROOT_DIR=$(eval echo "$tmp_root")
ENV_FILE="$ROOT_DIR/.env"

if [[ -f "$ENV_FILE" ]]; then 
   echo "$ENV_FILE already exists. deleting it."
   rm -rf "$ENV_FILE"
fi

write_env_file() {
    local output_file="$1"          # First argument: file to write to
    local torrentsctl_root_dir="$2" # Second argument: value for TORRENTSCTL_ROOT_DIR

    # Validate input
    if [[ -z "$output_file" || -z "$torrentsctl_root_dir" ]]; then
        echo "[error] invalid arguments!"
        return 1
    fi

    # Write to the file
    cat <<EOF >> "$output_file"
TORRENT_ROOT="$torrentsctl_root_dir"
LOGGING="\$TORRENT_ROOT/scripts/logging.sh"
LOG_DIR="\$TORRENT_ROOT/logs"
LOG_FILE="\$LOG_DIR/torrentctl.log"
STATUS_FUNCS="\$TORRENT_ROOT/scripts/status-funcs.sh"
EOF

    # Confirm action
    echo "Environment File at location '$output_file' has been updated with the following content:"
    cat "$output_file"
}

write_env_file "$ENV_FILE" "$ROOT_DIR"

if [[ -f "$ENV_FILE" ]]; then
   source "$ENV_FILE"
else
   echo "[error] generating .env file"
   exit 1
fi

mkdir -p "$LOG_DIR"
chmod -R 777 "$LOG_DIR"
touch "$LOG_FILE"
current_time=$(date +"%Y-%m-%d %H:%M:%S")
echo "Log file creation on $current_time" >> "$LOG_FILE"
echo "Log directory is $LOG_DIR" >> "$LOG_FILE"
echo "Log file path is $LOG_FILE" >> "$LOG_FILE"
echo "==== start here ====" >> "$LOG_FILE"
