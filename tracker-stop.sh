
#!/bin/bash

app=torrents

YELLOW='\033[0;33m'
BLUE='\033[0;35m'
RED='\033[0;31m'
NC='\033[0m' # No Color
pecho2() { echo -e "${BLUE}$1${NC}"; }
log2() { pecho2 "$@"; }
pecho1() { echo -e "${YELLOW}$1${NC}"; }
log1() { pecho1 "$@"; }
pecho() { echo -e "${RED}$1${NC}"; }
log() { pecho "$@"; }
error() { log "ERROR: $@" >&2; }
fatal() { error "$@"; exit 1; }
try() { "$@" || fatal "'$@' failed"; }
usage_fatal() { usage >&2; pecho "" >&2; fatal "$@"; }



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
        echo "Error: Container '$container_dir' not found"
        return ""
    fi
    echo "${container_dir}" # Return the first 12 characters of the container ID
}

human_readable() {
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

log2 "Stopping Monitor Loop... wait 2 seconds."

MONITOR_LOOP_STATUS_FILE="/tmp/monitor_loop.txt"
echo "0" > "$MONITOR_LOOP_STATUS_FILE"

sleep 2

CONTAINERDIR=``

log2 "getting container id for \"$app\""

var_cont_name=$(f_container_name "$app")

log2 "found container id \"$var_cont_name\""

log2 "getting uid for \"$var_cont_name\""
container_uid=$(get_container_uid $var_cont_name)

log1 "stopping container uid \"$container_uid\""

docker stop $container_uid

