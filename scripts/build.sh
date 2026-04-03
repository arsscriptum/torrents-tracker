#!/bin/bash

#+--------------------------------------------------------------------------------+
#|                                                                                |
#|   tamplate.sh                                                                  |
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
CLEAN_OPT=0
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
LOG_FILE="$LOGS_DIR/build.log"
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




# =========================================================
# function:     usage
# description:  display help message
#              
# =========================================================

usage() {
    echo "Usage: $0 [options]"  
    echo "  -c, --clean             Completely rebuilds images without cache, which ensures no old layers are reused"
    echo "  -i, --incremental       Incremental build"
    echo "  -a, --async             Runs the containers in the background (detached mode)"
    echo "  -t, --tag               Tag Build"
    echo "  -d, --debug             DEBUG MODE (no VPN)"
    echo "  -r, --run               Run the image as well"
    echo "  -V, --update-version    Update Version"
    echo "  -h, --help              Show this help message"
    exit 0
}


# =========================================================
# function:     logs functions
# description:  log messages to fils and console
#              
# =========================================================

log_info() {
    if [[ -f "$LOG_FILE" ]]; then
        echo "[$(date)] $1" >> "$LOG_FILE"
    fi
    echo -e "${BLUE}[log]${NC} $1"
}
log_warn() {
    if [[ -f "$LOG_FILE" ]]; then
        echo "[$(date)] $1" >> "$LOG_FILE"
    fi
    echo -e "${MAGENTA}[warn]${NC} ${WHITE}$1${NC}"
}
log_error() {
    if [[ -f "$LOG_FILE" ]]; then
        echo "[$(date)] $1" >> "$LOG_FILE"
    fi
    echo -e "${RED}[error]${NC} ${YELLOW}$1${NC}"
    exit 1
}


# =========================================================
# function:     get_next_filename
# description:  get a unique filename  for logs
#              
# =========================================================

get_next_filename() {
    local base_file="$1"
    local max_suffix=9
    local next_file=""

    for i in $(seq 0 $max_suffix); do
        next_file="${base_file}.${i}"
        if [[ ! -e "$next_file" ]]; then
            echo "$next_file"
            return
        fi
    done

    next_file="${base_file}.0"
    rm -rf $next_file
    echo "$next_file"
    return
}


if [[ ! -d "$LOGS_DIR" ]]; then
   mkdir -p "$LOGS_DIR"
   chmod -R 777 "$LOGS_DIR"
   log_info "Creating \"$LOGS_DIR\""
fi


if [[ -f "$LOG_FILE" ]]; then
    next_file=$(get_next_filename "$LOG_FILE")
    log_info "Next available filename: $next_file"
    log_info "Backup of log file \"$next_file\""
    mv -f "$LOG_FILE" "$next_file"
fi

BUILD_START_TIME=$(date +"%Y-%m-%d %H:%M:%S")
echo -e  "\n\n ========== BUILD STARTED ON $BUILD_START_TIME ========== \n" > "$LOG_FILE"

# Set the log level (e.g., DEBUG, INFO, WARNING, ERROR, CRITICAL).
LOG_LEVEL="WARNING"

while [[ $# -gt 0 ]]; do
    case "$1" in
        -V|--update-version)
            UPDATE_VERSION_OPT=1
            if [[ $# -gt 1 && ! "$2" =~ ^- ]]; then
                USER_VERSION="$2"
                if [[ ! $USER_VERSION =~ ^[0-9]+.[0-9]+.[0-9]+$ ]]; then
                    log_error "Specified Version \"$USER_VERSION\" format is invalid"
                    exit 1
                fi

                shift # Shift past the version
            fi
            ;;
        -l|--log-level)
            if [[ $# -gt 1 && ! "$2" =~ ^- ]]; then
                NEW_LOG_LEVEL="$2"
                if [[ "$NEW_LOG_LEVEL" == "DEBUG" || "$NEW_LOG_LEVEL" == "INFO" || "$NEW_LOG_LEVEL" == "WARNING" || "$NEW_LOG_LEVEL" == "ERROR" || "$NEW_LOG_LEVEL" == "CRITICAL"  ]]; then
                    LOG_LEVEL=$NEW_LOG_LEVEL
                    log_info "Specified Log Level \"$NEW_LOG_LEVEL\""
                else
                    log_warning "Specified Log Level \"$NEW_LOG_LEVEL\" is invalid. Set the log level to any of (DEBUG, INFO, WARNING, ERROR, CRITICAL)."
                fi
            else 
                log_warning "missing log level"
            fi
            shift # Shift past the version
            ;;
        -a|--async)
            ASYNC_OPT=1
            ;;
        -r|--run)
            RUN_OPT=1
            ;;
        -i|--incremental)
            INCREMENTAL_OPT=1
            ;;
        -d|--debug)
            LOG_LEVEL="DEBUG"
            DEBUG_OPT=1
            ;;
        -c|--clean)
            CLEAN_OPT=1
            ;;
        -t|--tag)
            TAG_OPT=1
            ;;
        -h|--help)
            usage
            ;;
    esac
    shift # Move to the next argument
done


if [[ "$TAG_OPT" -eq 1 && -z "$USER_VERSION" ]]; then
    log_error "if you specify --tag, you need to set the version verbatim. Example \"--update-version 4.2.0 --tag\""
fi

if [[ "$UPDATE_VERSION_OPT" -eq 1 ]]; then
    if [[ ! -z "$USER_VERSION" ]]; then
        log_version "Version specified: $USER_VERSION"
        if [[ ! $USER_VERSION =~ ^[0-9]+.[0-9]+.[0-9]+$ ]]; then
            log_info "Specified Version \"$USER_VERSION\" format is invalid"
            exit 1
        else
            echo "$USER_VERSION" > "$VERSION_FILE"

            # Get Git info
            current_branch=$(git branch --show-current)
            head_rev=$(git log --format=%h -1)
            last_rev=$(git log --format=%h -2 | tail -n 1)

            # Write the Git branch and revision information to build.nfo
            {
                echo "$current_branch"
                echo "$head_rev"
            } > "$BUILD_FILE"
            log_version "Version updated to $USER_VERSION"
            log_version "Branch ($current_branch) and revision ($head_rev) info saved to $BUILD_FILE"
        fi
    
    else
        log_version "No version specified."
        "$VERSION_SCRIPT"
    fi
fi

if [[ "$TAG_OPT" -eq 1 ]]; then
    CURRENT_VERSION=$(cat "$VERSION_FILE")
    log_info "Local Tag \"$CURRENT_VERSION\""
    git tag "$CURRENT_VERSION"
    log_warning "Remote Tag \"$CURRENT_VERSION\""
    git push origin "$CURRENT_VERSION"
    exit 0
fi


log_info "Updating docker-compose file..."

if [[ "$DEBUG_OPT" -eq 1 ]]; then
  log_info "DEBUG MODE: selected the development environment: not using VPN"
  cp --verbose --force $COMPFILE_DEVELOPMENT $COMPFILE_PATH
  update_build_time start 
  docker-compose up
  exit 0
else
  log_info "PRODUCTION MODE: You selected the production environment: using VPN"
  cp --verbose --force $COMPFILE_PRODUCTION $COMPFILE_PATH
fi


update_build_time start 
update_current_state "building"

if [[ "$CLEAN_OPT" -eq 1 ]]; then
    log_info "[Mode: CLEAN BUILD] Rebuilding Containerfrom Scratch, not using previous build cache"
    docker-compose build --no-cache --force-rm --parallel --build-arg ENV=production
    update_build_time end
elif [[ "$INCREMENTAL_OPT" -eq 1 ]]; then
    log_info "[Mode: FAST INCREMENTAL BUILD] Fast Container Build, using previous build cache."
    update_build_time end
else
    log_info "[Mode: BUILD] Container Build forcing container recreate"
    docker-compose build --force-rm --parallel --build-arg ENV=production
    update_build_time end
fi

# Check if the build was successful
if [ $? -eq 0 ]; then
  log_ok "Docker Compose project built successfully."
else
  log_warning "Failed to build the Docker Compose project."
  update_current_state "build-failed"
fi


exit $RESULT