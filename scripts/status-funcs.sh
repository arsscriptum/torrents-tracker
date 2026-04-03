#!/bin/bash

SCRIPT_PATH=$(realpath "$BASH_SOURCE")
SCRIPT_DIR=$(dirname "$SCRIPT_PATH")

tmp_root=$(pushd "$SCRIPT_DIR/.." | awk '{print $1}')
ROOT_DIR=$(eval echo "$tmp_root")
ENV_FILE="$ROOT_DIR/.env"

TMP_JSON_FILE="/tmp/tmp_state.json"

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

# set it to root for now, may have to set it to something like /state/bleh.json
STATUS_PATH="$ROOT_DIR/run"

mkdir -p "$STATUS_PATH"

JSON_FILE="$STATUS_PATH/state.json"
MONITORING_LOGFILE="$LOGS_DIR/health_checks.log"

UNL='\033[4;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

OWNER="arsscriptum"
TRACKER_IMAGENAME="torrents-tracker"
TRANSOVPN_IMAGENAME="docker.transmission-openvpn"
IMAGETAG="latest"
MIN_VALID_UNIX_TIME=999999999

log_debug() {
    local cred='\033[0;31m'
    local cyel='\033[0;33m'
    local cnc='\033[0m'
   echo -e "  ${cred}DBG⌦${cnc}   ${cyel}$1${cnc}" > "/dev/stderr"
}

# ======================================-----------------------======================================
# ====================================== CONVERSION  FUNCTIONS ======================================
# ======================================-----------------------======================================

# Function to convert a timestamp to human-readable format
convert_timestamp() {
    local timestamp="$1"

    # Validate input
    if [[ -z "$timestamp" || ! "$timestamp" =~ ^[0-9]+$ ]]; then
        echo "Usage: convert_timestamp <timestamp>"
        return 1
    fi

    # Convert timestamp to human-readable format
    local converted=$(date -d @"$timestamp" +"%Y-%m-%d %H:%M:%S")
    if [[ $? -ne 0 ]]; then
        converted=0
    fi
    return $converted
}


convert_to_unix() {
    local timestamp="$1"
    # Remove the last three-letter timezone abbreviation (if present)
    local cleaned_timestamp=$(echo "$timestamp" | sed -E 's/ [A-Z]{3}$//')
    
    #log_debug "Convert to Unix timestamp cleaned_timestamp $cleaned_timestamp . timestamp $timestamp"
    local converted=$(date -d "$cleaned_timestamp" +"%s")
    #log_debug "converted $converted"
    if [[ -z "$converted" || $? -ne 0 ]]; then
        converted=0
    fi
    echo "$converted"
}


# Function to convert a timestamp to human-readable format
convert_epoc_timestamp() {
    local timestamp="$1"
  
    # Validate input
    if [[ -z "$timestamp" || ! "$timestamp" =~ ^0|[1-9]\d*$ ]]; then
        echo "invalid timestamp format (should be a number (secs since  epoch)"
        return 1
    fi

    # Convert timestamp to human-readable format
    
    local converted=$(date -d @"$timestamp" +"%Y-%m-%d %H:%M:%S")
    if [[ $? -ne 0 ]]; then
        converted=0
    fi
    return $converted
}


convert_iso8601_timestamp() {
    local timestamp="$1"

    # Validate input
    if [[ -z "$timestamp" || ! "$timestamp" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}[+-][0-9]{2}:[0-9]{2}$ ]]; then
        echo "Invalid timestamp format (should be ISO8601: YYYY-MM-DDTHH:MM:SS±HH:MM)"
        return 1
    fi

    # Convert ISO8601 timestamp to Unix epoch
    local timestamp_epoch
    timestamp_epoch=$(date --date="$timestamp" +%s)

    # Convert timestamp to human-readable format
    
    local converted=$(date -d @"$timestamp_epoch" +"%Y-%m-%d %H:%M:%S")
    if [[ $? -ne 0 ]]; then
        converted=0
    fi
    return $converted
}


# ======================================-----------------------======================================
# ======================================   DEFAULT STATE FILE  ======================================
# ======================================-----------------------======================================


# Function to generate a JSON file with default values
generate_default_json() {
    local json_file=${1:-state.json}  # Default file name is state.json if not provided

    # JSON content with default values
    cat <<EOF > "$json_file"
{
  "current_state": "stopped", 
  "log_path": "$LOG_FILE",
  "started_on": 0,
  "ended_on": 0,
  "health": {
    "tested_on": 0,
    "intervals": 0,
    "is_healthy": 0,
    "reason": ""
  },
  "torrents-tracker": {
    "ID": "",
    "state": "",
    "creation_date": "",
    "uptime": "",
    "age": "",
    "memory_peak_h": "",
    "memory_current_h": "",
    "current_status": "",
    "is_running": "",
    "is_paused": "",
    "id_dead": "",
    "is_restarting": "",
    "memory_current": 0,
    "memory_peak": 0,
    "pid": 0,
    "cpu_usage": 0,
    "cpu_system": 0,
    "age_in_minutes": 0
  },
  "docker.transmission-openvpn": {
    "ID": "",
    "state": "",
    "creation_date": "",
    "uptime": "",
    "age": "",
    "memory_peak_h": "",
    "memory_current_h": "",
    "current_status": "",
    "is_running": "",
    "is_paused": "",
    "id_dead": "",
    "is_restarting": "",
    "memory_current": 0,
    "memory_peak": 0,
    "pid": 0,
    "cpu_usage": 0,
    "cpu_system": 0,
    "age_in_minutes": 0
  },
  "build": {
    "started_on": 0,
    "ended_on": 0,
    "build_result": 0
  }
}
EOF

    echo "Default JSON file generated: $json_file"
}

# ======================================-----------------------======================================
# ======================================   MAIN    FUNCTIONS   ======================================
# ======================================-----------------------======================================


f_container_name()
{
    docker ps --format "{{.Names}}"| grep -i $app
}

 
get_container_uid() 
{
    local container_name="$1"


    local container_id
    container_id=$(docker inspect --format="{{.Id}}" "$container_name" 2>/dev/null)

    if [ -z "$container_id" ]; then
        echo "Error: Container '$container_name' not found"
        return 1
    fi

    echo "${container_id:0:12}" # Return the first 12 characters of the container ID
}


get_container_directory() 
{
    local container_uid="$1"

    local container_dir
    container_dir=$(find /sys/fs/cgroup/system.slice  -type d | grep $container_uid)
    if [ -z "$container_dir" ]; then
        return ""
    fi
    echo "${container_dir}" # Return the first 12 characters of the container ID
}

human_readable_memory() {
    local bytes=$1
    local result=""
    if [ "$bytes" -ge $((1024**3)) ]; then
        result=$(echo "scale=2; $bytes / (1024^3)" | bc)
        echo "${result} GB"
    elif [ "$bytes" -ge $((1024**2)) ]; then
        result=$(echo "scale=2; $bytes / (1024^2)" | bc)
        echo "${result} MB"
    elif [ "$bytes" -ge 1024 ]; then
        result=$(echo "scale=2; $bytes / 1024" | bc)
        echo "${result} KB"
    else
        echo "${bytes} Bytes"
    fi
}


# Function to extract memory and CPU stats in JSON format
get_cgroup_stats() {
    local path="$1"
    
    # Ensure the provided path exists
    if [[ ! -d "$path" ]]; then
        echo "Error: Invalid path" >&2
        return 1
    fi

    # Extract memory usage details
    local memory_current=$(cat "$path/memory.current" 2>/dev/null || echo 0)
    local memory_peak=$(cat "$path/memory.peak" 2>/dev/null || echo 0)
    
    # Extract CPU usage details
    local cpu_usage_usec=$(grep "usage_usec" "$path/cpu.stat" 2>/dev/null | awk '{print $2}')
    local cpu_system_usec=$(grep "system_usec" "$path/cpu.stat" 2>/dev/null | awk '{print $2}')

    # Ensure values exist
    cpu_usage_usec=${cpu_usage_usec:-0}
    cpu_system_usec=${cpu_system_usec:-0}
    
    # Return JSON formatted output
    echo "{\"memory_current\": $memory_current, \"memory_peak\": $memory_peak, \"cpu_usage_usec\": $cpu_usage_usec, \"cpu_system_usec\": $cpu_system_usec }"
}

log_health_checks() {
    echo -e "[$(date)] $1" >> "$MONITORING_LOGFILE"
}


update_current_state() {
    local new_state="$1"  # First argument: new state value
    local temp_file=$(mktemp)
    if [[ -z "$new_state" ]]; then
        echo "[error] invalid state"
        return 1
    fi

    # Update current_state in the JSON file
    jq --arg state "$new_state" '.current_state = $state' "$JSON_FILE" > "$temp_file" && mv -f "$temp_file" "$JSON_FILE"
    #log_ok "Updated current_state to '$new_state' in $JSON_FILE."
}


update_log_file() {
    local file_path="$1"  # First argument: new state value
    local temp_file=$(mktemp)
    if [[ -f "$file_path" ]]; then
        echo "[error] invalid file path"
        return 1
    fi

    # Update current_state in the JSON file
    jq --arg state "$file_path" '.log_path = $file_path' "$JSON_FILE" > "$temp_file" && mv -f "$temp_file" "$JSON_FILE"
    #log_ok "Updated current_state to '$new_state' in $JSON_FILE."
}


# Function to update build start or end time
update_run_time() {
    local type="$1"       # First argument: "start" or "end"
    local time="$2"       # Second argument: timestamp (optional)

    local temp_file=$(mktemp)

    # Validate the type argument
    if [[ "$type" != "start" && "$type" != "end" ]]; then
        echo "[error] usage is \"update_run_time <start|end> [time]\""
    else
        # Use current timestamp if no time is provided
        if [[ -z "$time" ]]; then
            time=$(date +%s)
        fi

        # Update the appropriate field in the JSON file
        jq --argjson time "$time" ".${type}ed_on = \$time" "$JSON_FILE" > "$temp_file" && mv -f "$temp_file" "$JSON_FILE"

        # Confirm the update
        #log_ok "Updated run time .${type}ed_on to '$time' in $JSON_FILE."
    fi
}

# Function to update build start or end time
update_build_time() {
    local type="$1"       # First argument: "start" or "end"
    local time="$2"       # Second argument: timestamp (optional)
    local temp_file=$(mktemp)

    # Validate the type argument
    if [[ "$type" != "start" && "$type" != "end" ]]; then
        echo "[error] usage is \"update_build_time <start|end> [time]\""
    else 
        # Use current timestamp if no time is provided
        if [[ -z "$time" ]]; then
            time=$(date +%s)
        fi

        # Update the appropriate field in the JSON file
        jq --argjson time "$time" ".build.${type}ed_on = \$time" "$JSON_FILE" > "$temp_file" && mv -f "$temp_file" "$JSON_FILE"

        # Confirm the update
        #log_ok "Updated build.${type}ed_on to '$time' in $JSON_FILE."
    fi
}

update_health_check() {
    local healthy_state="$1"
    local temp_file=$(mktemp)

    # Use current timestamp if no time is provided
    if [[ -z "$healthy_state" ]]; then
        echo "[error] missing healthy_state"
    else

        if [[ -z "$healthy_state" || ! "$healthy_state" =~ ^[0-1]+$ || "$healthy_state" -lt 0 || "$healthy_state" -gt 1 ]]; then
            log_error "invalid value for healthy state ($healthy_state): must be a number between 0 and 1"
        else 
            jq --argjson healthy_state "$healthy_state" ".health.is_healthy = \$healthy_state" "$JSON_FILE" > "$temp_file" && mv -f "$temp_file" "$JSON_FILE"
            
            time=$(date +%s)
            jq --argjson time "$time" ".health.tested_on = \$time" "$JSON_FILE" > "$temp_file" && mv -f "$temp_file" "$JSON_FILE"

            #log_ok "Updated .health.is_healthy to \"$healthy_state\" .health.tested_on to '$time' in $JSON_FILE."
        fi
    fi
}


get_current_state() {
    jq -r '.current_state' "$JSON_FILE"
}

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

update_health_intervals() {
    local new_value="$1"  # First argument: new interval value
    local temp_file=$(mktemp)
    log_test "[update_health_intervals] updating the health checks intervals to $new_value seconds"

    # Validate input: Check if new_value is a number and within range
    if [[ -z "$new_value" || ! "$new_value" =~ ^[0-9]+$ || "$new_value" -lt 0 || "$new_value" -gt 120 ]]; then
        log_error "invalid interval ($new_value): must be a number between 0 and 120"
    else 
        # Update health.intervals in the JSON file
        jq --argjson new_value "$new_value" '.health.intervals = $new_value' "$JSON_FILE" > "$temp_file" && mv -f "$temp_file" "$JSON_FILE"
        #log_ok "Updated health.intervals to '$new_value' in $JSON_FILE."    
    fi
}




get_build_time() {
    local type="$1"       # First argument: "start" or "end"

    if [[ "$type" != "start" && "$type" != "end" ]]; then
        echo "[error] usage is \"get_build_time <start|end>\""
        return 1
    fi

    jq -r ".build.${type}ed_on" "$JSON_FILE"

}


if [[ ! -f "$JSON_FILE" ]]; then
   generate_default_json "$JSON_FILE"
fi



# Function to update the is_healthy flag
update_is_healthy() {
    local temp_file=$(mktemp)
    local is_healthy="$1"
    jq --argjson healthy "$is_healthy" '.health.is_healthy = $healthy' "$JSON_FILE" > "$temp_file" && mv -f "$temp_file" "$JSON_FILE"
    #echo "Updated is_healthy to $is_healthy."
}

update_health_uptime() {
    local is_healthy="$1"
    jq --argjson healthy "$is_healthy" '.health.is_healthy = $healthy' "$JSON_FILE" > "$temp_file" && mv -f "$temp_file" "$JSON_FILE"
    #echo "Updated is_healthy to $is_healthy."
}

# Function to get the current health check interval
get_health_intervals() {
    jq -r '.health.intervals' "$JSON_FILE"
}

# Function to get the last tested time
get_last_tested_time() {
    jq -r '.health.tested_on' "$JSON_FILE"
}

# Function to update the last tested time
update_last_tested_time() {
    local timestamp=$(date +%s)
    local temp_file=$(mktemp)
    jq --argjson tested_on "$timestamp" '.health.tested_on = $tested_on' "$JSON_FILE" > "$temp_file" && mv -f "$temp_file" "$JSON_FILE"
    #echo "Updated tested_on to $timestamp."
}

vpn_container_test() {

    local vpn_cnt_id=$(jq -r '."docker.transmission-openvpn".ID' "$JSON_FILE")
    local vpn_cnt_script_path="/scripts/check-vpn.sh"
    local local_script_path="$SCRIPT_DIR/check-vpn.sh"  # Update this path if needed

    # Check if the script exists inside the container
    if ! docker exec "$vpn_cnt_id" test -f "$vpn_cnt_script_path"; then
        docker cp "$local_script_path" "$vpn_cnt_id":"$vpn_cnt_script_path"
        
        # Verify if the copy was successful
        if ! docker exec "$vpn_cnt_id" test -f "$vpn_cnt_script_path"; then
            return 1
        fi
    fi

    if ! docker exec $vpn_cnt_id $vpn_cnt_script_path; then
        log_error "vpn  check failed"
        return 1
    fi 

    return 0
}

are_both_containers_running() {
     vpn_state=$(jq -r '."docker.transmission-openvpn".state' "$JSON_FILE")
     www_state=$(jq -r '."torrents-tracker".state' "$JSON_FILE")

    local vpn_health_status=$(docker inspect $(jq -r '."docker.transmission-openvpn".ID' "$JSON_FILE") | jq -r .[0].State.Health.Status)
    local www_health_status=$(docker inspect $(jq -r '."torrents-tracker".ID' "$JSON_FILE") | jq -r .[0].State.Status)
    if [[ "$www_state" == "running" && "$vpn_state" == "running" && "$vpn_health_status" == "healthy" && "$www_health_status" == "running" ]]; then
        return 0
    fi

    return 1
}



is_building() {
    local current=$(get_current_state)
    if [[ "$current" == "building" ]]; then
        return 0  # True
    else
        return 1  # False
    fi
}

is_running() {
    local current=$(get_current_state)
    if [[ "$current" == "running" ]]; then
        return 0  # True
    else
        return 1  # False
    fi
}


do_update_container_test() {
    tmp_owner="arsscriptum"
    tmp_tag="latest"
   # tmp_image="torrents-tracker"
    tmp_image="docker.transmission-openvpn"
    tmp_tracker_network="torrents-tracker_default"
    JSON_FILE="/home/services/torrents-tracker/run/state.json"
    temp_file=$(mktemp)
    current_time=$(date +%s)
    json_data=$(docker ps --format json | jq -r ". | select(.Image == \"$tmp_owner/$tmp_image:$tmp_tag\")")
    json_data=$(docker ps --format json | jq -r ". | select(.Image == \"$tmp_owner/$tmp_image:$tmp_tag\" and .Networks != \"firefoxvpn_default\")")
}

do_update_container_states() {
    local tmp_image="$1"

    # Validate input
    if [[ -z "$tmp_image" ]]; then
        log_health_checks " ❗❗❗ Usage: do_update_container_states <tmp_image>"
        return 1
    fi

    log_health_checks " ⚠ do_update_container_states ☛ $tmp_image"

    local tmp_owner="arsscriptum"
    local tmp_tag="latest"
    local tmp_tracker_network="torrents-tracker_default"
    local temp_file=$(mktemp)
    local current_time=$(date +%s)

    local json_data=$(docker ps --format json | jq -r ". | select(.Image == \"$tmp_owner/$tmp_image:$tmp_tag\" and .Networks != \"firefoxvpn_default\")")
    local json_inspect_data=$(docker inspect --format json $(echo $json_data | jq -r .ID) | jq -r .[0].State )

    local container_uid=$(echo $json_data | jq -r .ID)

    local cgroup_stat=$(get_cgroup_stats $(get_container_directory $container_uid))
    local memory_current=$(echo $cgroup_stat | jq -r .memory_current)
    local memory_current_h=$(human_readable_memory $memory_current)
    local memory_peak=$(echo $cgroup_stat | jq -r .memory_peak)
    local memory_peak_h=$(human_readable_memory $memory_peak)
    local cpu_usage_usec=$(echo $cgroup_stat | jq -r .cpu_usage_usec)
    local cpu_system_usec=$(echo $cgroup_stat | jq -r .cpu_system_usec)
  
    local val_Pid=$(echo $json_inspect_data | jq -r .Pid)
    local val_StatusStr=$(echo $json_inspect_data | jq -r .Status)
    local val_ErrorStr=$(echo $json_inspect_data | jq -r .Error)
    local val_IsRunning=$(echo $json_inspect_data | jq -r .Running)
    local val_IsPaused=$(echo $json_inspect_data | jq -r .Paused)
    local val_IsRestarting=$(echo $json_inspect_data | jq -r .Restarting)
    local val_IsDead=$(echo $json_inspect_data | jq -r .Dead)
    local val_ExitCode=$(echo $json_inspect_data | jq -r .ExitCode)
    local val_IsOOMKilled=$(echo $json_inspect_data | jq -r .OOMKilled)


    local val_ID=$(echo $json_data | jq -r .ID)
    local val_State=$(echo $json_data | jq -r .State)
    local val_CreatedAt=$(echo $json_data | jq -r .CreatedAt)
    local val_Status=$(echo $json_data | jq -r .Status)
    local val_RunningFor=$(echo $json_data | jq -r .RunningFor)
    local time_diff=0
    local minutes_since_creation=0
    local created_at_unix=$(convert_to_unix "$val_CreatedAt")
    if [[ $created_at_unix -le $MIN_VALID_UNIX_TIME ]]; then
        log_warning "error processing container creation time created_at_unix $created_at_unix MIN_VALID_UNIX_TIME $MIN_VALID_UNIX_TIME"
        created_at_unix=0
        minutes_since_creation=0
        time_diff=0
    else
        time_diff=$(($current_time - $created_at_unix))
        minutes_since_creation=$(($time_diff / 60))
    fi


    log_health_checks "[do_update_container_states] ID ➪ $val_ID"
    log_health_checks "[do_update_container_states] state ➪ $val_State"
    log_health_checks "[do_update_container_states] creation_date ➪ $val_CreatedAt"
    log_health_checks "[do_update_container_states] uptime ➪ $val_Status"
    log_health_checks "[do_update_container_states] age ➪ $val_RunningFor"
    log_health_checks "[do_update_container_states] age_in_minutes ➪ $minutes_since_creation"

    # Update JSON file
    jq --arg id "$val_ID" \
       --arg state "$val_State" \
       --arg created_at "$val_CreatedAt" \
       --arg uptime "$val_Status" \
       --arg age "$val_RunningFor" \
       --arg mcurrenth "$memory_current_h" \
       --arg mempeakh "$memory_peak_h" \
       --arg mcurrent $memory_current \
       --arg mempeak $memory_peak \
       --arg cpu_usage $cpu_usage_usec \
       --arg cpu_system $cpu_system_usec \
       --arg pid $val_Pid \
       --arg statusstr "$val_StatusStr" \
       --arg ErrorStr "$val_ErrorStr" \
       --arg IsRunning "$val_IsRunning" \
       --arg IsPaused "$val_IsPaused" \
       --arg IsRestarting "$val_IsRestarting" \
       --arg IsDead "$val_IsDead" \
       --arg ExitCode "$val_ExitCode" \
       --arg IsOOMKilled "$val_IsOOMKilled" \
       --argjson minutes "$minutes_since_creation" \
        ".[\"${tmp_image}\"].ID = \$id |
        .[\"${tmp_image}\"].state = \$state |
        .[\"${tmp_image}\"].memory_current_h = \$mcurrenth |
        .[\"${tmp_image}\"].memory_peak_h = \$mempeakh |
        .[\"${tmp_image}\"].memory_current = \$mcurrent |
        .[\"${tmp_image}\"].memory_peak = \$mempeak |
        .[\"${tmp_image}\"].cpu_usage = \$cpu_usage |
        .[\"${tmp_image}\"].cpu_system = \$cpu_system |
        .[\"${tmp_image}\"].pid = \$pid |
        .[\"${tmp_image}\"].current_status = \$statusstr |
        .[\"${tmp_image}\"].is_running = \$IsRunning |
        .[\"${tmp_image}\"].is_paused = \$IsPaused |
        .[\"${tmp_image}\"].id_dead = \$IsDead |
        .[\"${tmp_image}\"].is_restarting = \$IsRestarting |
        .[\"${tmp_image}\"].creation_date = \$created_at |
        .[\"${tmp_image}\"].uptime = \$uptime |
        .[\"${tmp_image}\"].age = \$age |
        .[\"${tmp_image}\"].age_in_minutes = \$minutes" "$JSON_FILE" > "$temp_file" && mv "$temp_file" "$JSON_FILE"
}


do_update_all_container() {
    log_health_checks "☛ do_update_all_container"
    do_update_container_states "docker.transmission-openvpn"
    do_update_container_states "torrents-tracker"
}

check_access() {
  local retval=0
  curl -s "http://10.0.0.111:7070/tracker/" | grep -q "/tracker/searchTorrents"
  if [ $? -ne 0 ]; then
    log_warning "[health] check_access failed: cannot acces torrents-tracker @ http://10.0.0.111:7070/tracker/"
    log_health_checks " ❗❗❗ check_access failed: cannot acces torrents-tracker @ http://10.0.0.111:7070/tracker/"
    return 1
  fi

  log_health_checks " ✔ [health] check_access Success"
  return 0
  
}


# Function to perform a health check
do_health_check() {
    local force=$1
    local interval=$(get_health_intervals)
    local last_tested=$(get_last_tested_time)
    local current_time=$(date +%s)
    local time_diff=$((current_time - last_tested))
    local execute=false
    local unhealthy_count=0
    local unhealthy_max_failures=3

    do_update_all_container

    if are_both_containers_running; then
        update_current_state "running"
    fi

    if vpn_container_test;  then
        log_health_checks " ⚡ vpn_container_test success"
    else 
        log_health_checks " ❌ vpn_container_test failed"
        jq --argjson healthy "error" '."docker.transmission-openvpn".state = error' "$JSON_FILE" > "$temp_file" && mv -f "$temp_file" "$JSON_FILE"
        jq --argjson healthy "vpn error" '."docker.transmission-openvpn".error_string = "vpn error"' "$JSON_FILE" > "$temp_file" && mv -f "$temp_file" "$JSON_FILE"
    fi 
    
    if $force; then 
        #log_info "[do_health_check] force specified"
        execute=true
    fi 

    if (( time_diff >= interval )); then
        execute=true
        #log_info "[do_health_check] time diff ($time_diff) greater than interval ($interval)"
    fi

    local activity_status_system=$(systemctl is-active torrents-tracker.service)
    log_health_checks " ⚡ systemctl is-active torrents-tracker.service --> $activity_status_system"

    if $execute; then
        log_health_checks "[do_health_check] performing health check... "
        local access_status=0
        local activity_status=0

        # Determine overall health
        if check_access; then
            update_is_healthy 1  # Healthy
            log_info "[do_health_check] performing health check... System is healthy."
            if [[ $unhealthy_count -gt 0 ]]; then
                unhealthy_count=0
                log_warning "[health] health check successn after $unhealthy_count previous failures. Resetting fail count."
            fi
        else
            if [[ $unhealthy_count -ge $unhealthy_max_failures ]]; then
                update_is_healthy 0  # Not healthy
                log_warning "[do_health_check] NOT HEALTHY $unhealthy_count / $unhealthy_max_failures"
            else
                unhealthy_count=$(($unhealthy_count + 1))
                log_warning "[do_health_check] NOT HEALTHY. unhealthy_count $unhealthy_count / $unhealthy_max_failures"
            fi
        fi

        # Update the last tested time
        update_last_tested_time
    fi
}


do_test() {

    local json_data1=$(docker ps --format json | jq -r ". | select(.Image == \"$OWNER/$TRACKER_IMAGENAME:$IMAGETAG\")")
    if [[ -z "$json_data1" ]]; then
        log_health_status " ❌ Cannot find Image \"$OWNER/$TRACKER_IMAGENAME:$IMAGETAG\""
    else 
        CURRENT_STATE=$(echo $json_data1 | jq -r .State)
        CREATION_TIME=$(echo $json_data1 | jq -r .RunningFor)
        CURRENT_STATUS=$(echo $json_data1 | jq -r .Status)
        CREATION_TIME_DATE=$(echo $json_data1 | jq -r .CreatedAt)
        CREATION_TIME_UNIX=$(convert_to_unix "$CREATION_TIME_DATE")


        log_health_checks " ⚡ \"$OWNER/$TRANSOVPN_IMAGENAME:$IMAGETAG\" ⚡ "
        log_health_checks " ✅ Currently $CURRENT_STATE. Time since creation $CREATION_TIME."
        log_health_checks " ✅ ${UNL}$CURRENT_STATUS${NC}"
    fi

    local json_data2=$(docker ps --format json | jq -r ". | select(.Image == \"$OWNER/$TRANSOVPN_IMAGENAME:$IMAGETAG\")")
    if [[ -z "$json_data2" ]]; then
        log_health_status " ❌ Cannot find Image \"$OWNER/$TRACKER_IMAGENAME:$IMAGETAG\""
    else 
        CURRENT_STATE=$(echo $json_data2 | jq -r .State)
        CREATION_TIME=$(echo $json_data2 | jq -r .RunningFor)
        CURRENT_STATUS=$(echo $json_data2 | jq -r .Status)
        log_health_checks " ⚡ \"$OWNER/$TRANSOVPN_IMAGENAME:$IMAGETAG\" ⚡ "
        log_health_checks " ✅ Currently $CURRENT_STATE. Time since creation $CREATION_TIME."
        log_health_checks " ✅ ${UNL}$CURRENT_STATUS${NC}"
    fi

}

