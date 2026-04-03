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

if [[ -f "$STATUS_FUNCS" ]]; then
   source "$STATUS_FUNCS"
else
   echo "[error] missing status functions file!"
   exit 3
fi

MONITOR_LOOP_STATUS_FILE="/tmp/monitor-docker-containers-5939-4b8b-b7c4.tmp"

monitor_loop() {
  # Ensure the control file exists
  if [[ ! -f "$MONITOR_LOOP_STATUS_FILE" ]]; then
      echo "1" > "$MONITOR_LOOP_STATUS_FILE"
  fi

  log_info "[monitor_loop] entering loop, intervals of 5 seconds"

  while true; do
      # Read the monitor file content
      local control=$(cat "$MONITOR_LOOP_STATUS_FILE")
      
      if [[ "$control" == "0" ]]; then
          log_info "[monitor_loop] received stop signal, exiting loop"
          break
      fi

      # Perform the health check
      do_health_check false
      
      # Wait before the next iteration
      sleep 5
  done

  log_info "[monitor_loop] exiting loop"
}

monitor_loop



update_health_intervals