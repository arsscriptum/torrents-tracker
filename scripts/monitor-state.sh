#!/bin/bash


SCRIPT_PATH=$(realpath "$BASH_SOURCE")
SCRIPT_DIR=$(dirname "$SCRIPT_PATH")

tmp_root=$(pushd "$SCRIPT_DIR/.." | awk '{print $1}')
ROOT_DIR=$(eval echo "$tmp_root")
ENV_FILE="$ROOT_DIR/.env"
ROOT_DIRECTORY="$ROOT_DIR"

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

ST_FUNCS="$SCRIPT_DIR/status-funcs.sh"

if [[ -f "$ST_FUNCS" ]]; then
   source "$ST_FUNCS"
else
   echo "[error] missing $ST_FUNCS file!"
   exit 1
fi

BRED='\033[2;31m'
DIM='\033[2;36m'
ITA='\033[3;32m'
UNL='\033[4;33m'
BGREEN='\033[0;92m'
BBLUE='\033[0;95m'       
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Variables for cmd arguments
CLEAN_OPT=0
DEBUG_OPT=0
DRYRUN_OPT=0
MONITOR_OPT=0
FILENAME_OPT=0
REFRESHRATE_OPT=0  # Default interval value (can be overridden)

# default file name


# Once every 4 seconds
REFRESH_RATE=6

# Usage function
usage() {
    echo "Usage: $0 [options]"  
    echo "  -c, --clean                Do nothing, just test, logs"
    echo "  -r, --refreshrate <int>    Set refresh rate. once every x seconds."
    echo "  -f, --file <int>           Set initial value for health check intervals (seconds). Default if $DEFAULT_HEALTH_INTERVAL"
    echo "  -h, --help                 Show this help message"
    exit 0
}

# Parse script arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--clean)
            CLEAN_OPT=1
            shift
            ;;
        -d|--debug)
            DEBUG_OPT=1
            shift
            ;;
        -f|--file)
            if [[ $# -lt 2  ]]; then
                echo "[error] --file option requires a file path"
                exit 1
            fi
            FILENAME_OPT=1
            FILE_NAME=$2
            shift 2
            ;;
        -r|--refreshrate)
            if [[ $# -lt 2 || ! $2 =~ ^[0-9]+$ ]]; then
                echo "[error] --interval option requires a positive integer argument"
                exit 1
            fi
            REFRESHRATE_OPT=1
            REFRESH_RATE=$2
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

if [[ -z "$FILE_NAME" ]]; then 
    FILE_NAME="$ROOT_DIR/state.json"
fi 

log_info "[init] file path is \"$FILE_NAME\""

if [[ -f "$FILE_NAME" ]]; then
    log_info "[init] file \"$FILE_NAME\" exists, delete it."
    rm -rf "$FILE_NAME"
fi

log_info "[init] generate default json file..."
generate_default_json "$FILE_NAME"

DUMPED_CONTENT=$(cat "$FILE_NAME")

log_info "====================================="
log_info "$DUMPED_CONTENT"
log_info "====================================="


log_info "Parse file components"
DIR_NAME=$(dirname "$FILE_NAME")               # Directory name
BASE_NAME=$(basename "$FILE_NAME")             # Base name (with extension)
FNAME="${BASE_NAME%.*}"                    # File name (without extension)
EXTENSION="${BASE_NAME##*.}"                   # File extension

log_info "DIR_NAME $DIR_NAME"
log_info "BASE_NAME $BASE_NAME"
log_info "FNAME $FNAME"
log_info "EXTENSION $EXTENSION"


NEW_FILE="${DIR_NAME}/${FNAME}_old"
if [[ -n "$EXTENSION" ]]; then
    NEW_FILE="${NEW_FILE}.${EXTENSION}"
fi

log_info "\"$NEW_FILE\" Second file with \"_old\" added on basename"

if [[ -f "$NEW_FILE" ]]; then
    log_info "[init] file \"$NEW_FILE\" exists, delete it."
    rm -rf "$NEW_FILE"
fi

generate_default_json "$NEW_FILE"

JSON_FILE="$FILE_NAME"
BACKUP_FILE="$NEW_FILE"

if [[ "$DEBUG_OPT" -eq 1 ]]; then
    log_outmag "===================================================="
    log_info "will start monitoring file 1: \"$FILE_NAME\""

    cat "$FILE_NAME"

    log_info "will start monitoring file 2: \"$NEW_FILE\""

    cat "$NEW_FILE"

    log_outmag "===================================================="

    sleep 6
fi





states_path="/tmp/3be03b03-98ad-410a-b5e9"
rm -rf "$states_path"
mkdir -p "$states_path"


dump_two_values() {
    local val1=$1
    local val2=$2
    local uid=$3
    local width=20  # Adjust the width as needed for alignment
    local states_path="/tmp/3be03b03-98ad-410a-b5e9"
    local current_time=$(date +%s)
    local state_ttl=6
    local state_file="$states_path/state.$uid"
    local time_file="$states_path/time.$uid"
    local state="test"

    # Determine state based on values and manage TTL
    if [[ -f "$state_file" && -f "$time_file" ]]; then
        # Get existing state and timestamp
        #grep -q "red" "$state_file"
        if grep -q "red" "$state_file"; then
            echo "yellow" > "$state_file"
            state="yellow"
        fi
        if grep -q "yellow" "$state_file"; then
            echo "blue" > "$state_file"
            state="blue"
        fi
        last_time=$(cat "$time_file")

        # Check if TTL has expired
        if (( current_time - last_time > state_ttl )); then
            # TTL expired, reset state
            rm -f "$state_file" "$time_file"
            state="blue"

        fi
    fi

    # If state is not set or was reset, determine the new state
    
    if [[ "$val1" != "$val2" ]]; then
        state="red"
    else
        state="test"
    fi
    echo "$state" > "$state_file"
    echo "$current_time" > "$time_file"
    
    case "$state" in
        red)
            printf "${CYAN}%-20s${NC} ${RED}%-20s${NC}\n" "$val1" "$val2"
            # Add commands to start the service here
            ;;
        yellow)
            printf "${CYAN}%-20s${NC} ${ITA}%-20s${NC}\n" "$val1" "$val2"
            # Add commands to stop the service here
            ;;
        blue)
            printf "${CYAN}%-20s${NC} ${MAGENTA}%-20s${NC}\n" "$val1" "$val2"
            # Add commands to restart the service here
            ;;
        *)
            printf "%-20s %-20s\n" "$val1" "$val2"
            # Add commands to check service status here
            ;;
    esac
}




update_json_values() {
    OLD_VAL1=0
    NEW_VAL1=0
    OLD_VAL2=""
    NEW_VAL2=""
    OLD_VAL3=0
    NEW_VAL3=0
    OLD_VAL4=0
    NEW_VAL4=0
    OLD_VAL5=0
    NEW_VAL5=0
    OLD_VAL6=0
    NEW_VAL6=0
    OLD_VAL7=0
    NEW_VAL7=0
    OLD_VAL8=0
    NEW_VAL8=0
    OLD_VAL9=0
    NEW_VAL9=0
    OLD_VAL10=0
    NEW_VAL10=0


    OLD_VAL1=$(jq -r '.current_state' "$BACKUP_FILE")
    NEW_VAL1=$(jq -r '.current_state' "$JSON_FILE")
    OLD_VAL2=$(jq -r '.log_path' "$BACKUP_FILE")
    NEW_VAL2=$(jq -r '.log_path' "$JSON_FILE")
    OLD_VAL3=$(jq -r '.started_on' "$BACKUP_FILE")
    NEW_VAL3=$(jq -r '.started_on' "$JSON_FILE")
    OLD_VAL4=$(jq -r '.ended_on' "$BACKUP_FILE")
    NEW_VAL4=$(jq -r '.ended_on' "$JSON_FILE")
    OLD_VAL5=$(jq -r '.health.tested_on' "$BACKUP_FILE")
    NEW_VAL5=$(jq -r '.health.tested_on' "$JSON_FILE")
    OLD_VAL6=$(jq -r '.health.intervals' "$BACKUP_FILE")
    NEW_VAL6=$(jq -r '.health.intervals' "$JSON_FILE")
    OLD_VAL7=$(jq -r '.health.is_healthy' "$BACKUP_FILE")
    NEW_VAL7=$(jq -r '.health.is_healthy' "$JSON_FILE")
    OLD_VAL8=$(jq -r '.build.started_on' "$BACKUP_FILE")
    NEW_VAL8=$(jq -r '.build.started_on' "$JSON_FILE")
    OLD_VAL9=$(jq -r '.build.ended_on' "$BACKUP_FILE")
    NEW_VAL9=$(jq -r '.build.ended_on' "$JSON_FILE")
    OLD_VAL10=$(jq -r '.build.build_result' "$BACKUP_FILE")
    NEW_VAL10=$(jq -r '.build.build_result' "$JSON_FILE")

    log_outmag "╔═════════════════════╦════════════╦═════════════════╗"
    log_outmag "║   json schema       ║     old    ║     new         ║"
    log_outmag "╚═════════════════════╩════════════╩═════════════════╝"
    echo "{                                                     "
    echo "  \"current_state\":   $(dump_two_values $OLD_VAL1 $NEW_VAL1 "13799e3b8a1c")"
    echo "  \"log_path\":        $(dump_two_values $OLD_VAL2 $NEW_VAL2 "2b65051e5c46")"
    echo "  \"started_on\":      $(dump_two_values $OLD_VAL3 $NEW_VAL3 "f6a1e74c9ed8")"
    echo "  \"ended_on\":        $(dump_two_values $OLD_VAL4 $NEW_VAL4 "bd2e2d8de79f")"
    echo "  \"health\": {        "
    echo "    \"tested_on\":     $(dump_two_values $OLD_VAL5 $NEW_VAL5 "697a07050238")"
    echo "    \"intervals\":     $(dump_two_values $OLD_VAL6 $NEW_VAL6 "567937978484")"
    echo "    \"is_healthy\":    $(dump_two_values $OLD_VAL7 $NEW_VAL7 "d71a915dc682")"
    echo "  },  "
    echo "  \"build\": {         "
    echo "    \"started_on\":    $(dump_two_values $OLD_VAL8 $NEW_VAL8 "b8e64ee753e9")"
    echo "    \"ended_on\":      $(dump_two_values $OLD_VAL9 $NEW_VAL9 "a8e7e747d1fa")"
    echo "    \"build_result\":  $(dump_two_values $OLD_VAL10 $NEW_VAL10 "7eb40dfe2423")"
    echo "  }                                                   "
    echo "}                                                     "

}


# Initialize the counter
counter=0

while true; do
    

    # Increment the counter
    ((counter++))

    # Check if counter has reached REFRESH_RATE
    if [[ $counter -ge $REFRESH_RATE ]]; then
        # Reset the counter
        counter=0
        cp -f "$FILE_NAME" "$NEW_FILE"
    fi
    clear
    update_json_values
    # Sleep or delay between iterations (optional)
    sleep 1
done

