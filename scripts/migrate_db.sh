
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


# Check if the '--test' argument is passed
TEST_ONLY=""
# Check if '--test' is among the passed arguments
for arg in "$@"; do
  if [ "$arg" == "--test" ]; then
    TEST_ONLY="yes"
    break
  fi
  if [ "$arg" == "-t" ]; then
    TEST_ONLY="yes"
    break
  fi
done

FORCE_RECREATE=""
# Check if '--attach' is among the passed arguments
for arg in "$@"; do
  if [ "$arg" == "-r" ]; then
    log_info " Delete and Reapply Migrations (If Data Can Be Dropped)"
    FORCE_RECREATE="yes"
    break
  fi
  if [ "$arg" == "--recreate" ]; then
    log_info " Delete and Reapply Migrations (If Data Can Be Dropped)"
    FORCE_RECREATE="yes"
    break
  fi
done

# Check if the '--attach' argument is passed
ATTACHED_MODE=""
# Check if '--attach' is among the passed arguments
for arg in "$@"; do
  if [ "$arg" == "-a" ]; then
    log_info "Runs the migrate scripts in the container (attach mode) instead of keeping them out to the container"
    ATTACHED_MODE="yes"
    break
  fi
  if [ "$arg" == "--attach" ]; then
    log_info "Runs the migrate scripts in the container (attach mode) instead of keeping them out to the container"
    ATTACHED_MODE="yes"
    break
  fi
done

FAKE_MODE=""
# Check if '--attach' is among the passed arguments
for arg in "$@"; do
  if [ "$arg" == "-f" ]; then
    log_info "Fake the Migrations (Recommended for Existing Data) - Fake Apply the Migration Mark the migration as applied"
    FAKE_MODE="yes"
    break
  fi
  if [ "$arg" == "--fake" ]; then
    log_info "Fake the Migrations (Recommended for Existing Data) - Fake Apply the Migration Mark the migration as applied"
    FAKE_MODE="yes"
    break
  fi
done

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

log_info "getting container id for \"$app\""

var_cont_name=$(f_container_name "$app")

log_info "found container id \"$var_cont_name\""

log_info "getting uid for \"$var_cont_name\""
container_uid=$(get_container_uid $var_cont_name)

log_info "found container uid \"$container_uid\""

if [ "$FORCE_RECREATE" == "yes" ]; then
    log_important "FORCE_RECREATE - delete files $ROOT_DIR/tracker/migrations/0*.py"
    find "$ROOT_DIR/tracker/migrations" -name "0*.py" -exec rm -rfv {} \;
fi

if [ "$FAKE_MODE" == "yes" ]; then
    log_important "source ./temp-env/bin/activate"
    log_important "Check Existing Migrations List the applied migrations: python manage.py showmigrations"
    log_important "Fake Apply the Migration Mark the migration as applied: python manage.py migrate tracker --fake"
    log_important "Retry Migrations Now, run the remaining migrations: python manage.py migrate"
    log_info "Runs the migrate scripts in the container (attach mode) instead of keeping them out to the container"
    docker exec -it $container_uid /bin/bash -c "source ./temp-env/bin/activate && python manage.py showmigrations && python manage.py migrate tracker --fake && python manage.py migrate &&  exec /bin/bash"
    exit 0
else
    log_title "================================================"
    log_info "source ./temp-env/bin/activate"
    log_info "python manage.py makemigrations tracker"
    log_info "python manage.py migrate"
    log_info "Runs the migrate scripts in the container (attach mode) instead of keeping them out to the container"
    docker exec -it $container_uid /bin/bash -c "source ./temp-env/bin/activate && python manage.py makemigrations tracker && python manage.py migrate"
fi


if [ "$ATTACHED_MODE" == "yes" ]; then
  docker exec -it $container_uid /bin/bash
fi

