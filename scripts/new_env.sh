
# ┌────────────────────────────────────────────────────────────────────────────────┐
# │                                                                                │
# │   migrate_db.sh                                                             │
# │                                                                                │
# └────────────────────────────────────────────────────────────────────────────────┘



YELLOW='\033[0;33m'
RED='\033[0;31m'
YELLOW='\033[0;93m'
DARKYELLOW='\033[0;33m'
CYAN='\033[0;36m'
MAG='\033[0;35m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color




# Handy logging and error handling functions
pecho() { printf %s\\n "$*"; }

log() { pecho "$@"; }

# Verbose output function
log_info() {
    echo -e "${RED} ➪   ${NC}${YELLOW}$1${NC}"
}

log_important1() {
    echo -e "${MAG} ⚐   ${NC}${CYAN}$1${NC}"
}
log_important() {
    echo -e "${YELLOW} ⚐   ${NC}${CYAN}$1${NC}"
}

log_title() {
    echo -e "${RED} ===== ${NC}${YELLOW}$1${NC}${RED} ===== ${NC}"
}
log_ok() {
    echo -e "✅ ${GREEN}$1${NC}"
}

log_warning() {
    echo -e "${YELLOW} ⚠   ${NC}${CYAN}$1${NC}"
}

log_error() {
    echo -e "${RED} ✘   ${NC}${YELLOW}$1${NC}"
}

log_test_chars() {
    echo -e "${YELLOW} 》 ☣ ⦿ ⮕ ➪ ➔ ❉ ⛌ ⚐ ⍟ ⊙ ⊛ ⇛ ➺ ➲ ➢ ⊳{NC}"
}

usage() {
  log_warning "Syntax: migrate_db.sh"
  log_warning "options: --attach : run in attach mode"
  log_warning "         --test: test only"
  exit 1
}


app=torrents


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


CONTAINERDIR=``
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

pushd "$SCRIPT_DIR/.."
ROOT_DIR=`pwd`
popd

docker ps | grep -q torrent
if [ "$?" == "1" ]; then
    log_error "No torrents-rtacker container is running"
fi

log_info "getting container id for \"$app\""

var_cont_name=$(f_container_name "$app")

if [ "$var_cont_name" == "" ]; then
    log_error "cannot find container id."
    log_important1 "source $ROOT_DIR/temp-env/bin/activate"
    #source $ROOT_DIR/temp-env/bin/activate
    exit 1
fi


log_info "found container id \"$var_cont_name\""

log_info "getting uid for \"$var_cont_name\""
container_uid=$(get_container_uid $var_cont_name)

log_info "found container uid \"$container_uid\""


docker exec -it $container_uid /bin/bash
