#!/bin/bash

DEFAULT_HEALTH_INTERVAL=60 

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

MONITOR_LOG_FILE="$LOG_DIR/monitor.log"
MONITOR_SCRIPT="$SCRIPT_DIR/do-monitoring.sh"

# Variables for cmd arguments
CLEAN_OPT=0
DRYRUN_OPT=0
MONITOR_OPT=0
HEALTH_INTERVAL=0  # Default interval value (can be overridden)

# Usage function
usage() {
    echo "Usage: $0 [options]"  
    echo "  -d, --dryrun         Do nothing, just test, logs"
    echo "  -m, --monitor        Monitor health of containers after launch"
    echo "  -i, --interval <int> Set initial value for health check intervals (seconds). Default if $DEFAULT_HEALTH_INTERVAL"
    echo "  -h, --help           Show this help message"
    exit 0
}

# Parse script arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--dryrun)
            DRYRUN_OPT=1
            shift
            ;;
        -m|--monitor)
            MONITOR_OPT=1
            shift
            ;;
        -i|--interval)
            if [[ $# -lt 2 || ! $2 =~ ^[0-9]+$ ]]; then
                echo "[error] --interval option requires a positive integer argument"
                exit 1
            fi
            HEALTH_INTERVAL_OPT=1
            HEALTH_INTERVAL=$2
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "[error] Invalid option: $1"
            usage
            ;;
    esac
done

# Log the health interval if specified
if [[ "$HEALTH_INTERVAL_OPT" -eq 1 ]]; then
    log_info "Specified HEALTH CHECKS Intervals: Setting health check interval to $HEALTH_INTERVAL seconds"
    update_health_intervals $HEALTH_INTERVAL
else 
    log_warning "Using DEFAULT value for HEALTH CHECKS Intervals. $HEALTH_INTERVAL seconds"
    update_health_intervals $DEFAULT_HEALTH_INTERVAL
fi

if [[ "$MONITOR_OPT" -eq 1 ]]; then
    log_info "[monitoring] starting the monitoring script in background, piping outputs in $MONITOR_LOG_FILE"
    $MONITOR_SCRIPT > "$MONITOR_LOG_FILE" 2>&1 &
    sleep 2
fi

if [[ "$DRYRUN_OPT" -eq 1 ]]; then
  log_test "waiting 15 seconds, simulating docker run containers..."
  sleep 15
else
  log_info "running \"docker-compose up --remove-orphans\""
  update_current_state "started"
  docker-compose up --remove-orphans
  if [ $RESULT -eq 0 ]; then
    log_ok "Docker Compose project built successfully."
  else
    log_warning "Failed to run the Docker Compose project."
  fi
fi 

update_run_time start



