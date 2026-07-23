#!/bin/bash

#+--------------------------------------------------------------------------------+
#|                                                                                |
#|   deploy-service.sh                                                            |
#|                                                                                |
#+--------------------------------------------------------------------------------+
#|   Guillaume Plante <planteg@proton.me>                                         |
#|   Code licensed under the GNU GPL v3.0. See the LICENSE file for details.      |
#+--------------------------------------------------------------------------------+
#
#   Syncs the dev directory to the service directory and optionally
#   rebuilds the Docker image and restarts the containers.
#
#   Usage:
#     deploy-service.sh [-b] [-r] [-s] [-h]
#
#   The live service reads from /home/services/torrents-tracker (volume mount),
#   not from the dev directory. This script bridges that gap.
#

SCRIPT_PATH=$(realpath "$BASH_SOURCE")
SCRIPT_DIR=$(dirname "$SCRIPT_PATH")

tmp_root=$(pushd "$SCRIPT_DIR/.." | awk '{print $1}')
ROOT_DIR=$(eval echo "$tmp_root")

ENV_FILE="$ROOT_DIR/.env"
LOGGING="$SCRIPT_DIR/logging.sh"
LOGS_DIR="$ROOT_DIR/logs"
LOG_FILE="$LOGS_DIR/deploy.log"

SERVICE_DIR="/home/services/torrents-tracker"
COMPFILE_PATH="$ROOT_DIR/docker-compose.yml"

BUILD_OPT=0
RESTART_OPT=0
START_OPT=0
STOP_OPT=0
RESTART_OPT=0
SYNC_ONLY_OPT=0

LogCategory="deploy-service"

# =========================================================
# Bootstrap
# =========================================================

if [[ ! -f "$ENV_FILE" ]]; then
    echo "[error] missing .env file @ \"$ENV_FILE\"!"
    exit 1
fi
source "$ENV_FILE"

if [[ ! -f "$LOGGING" ]]; then
    echo "[error] missing logging.sh @ \"$LOGGING\"!"
    exit 2
fi
source "$LOGGING"

if [[ ! -d "$LOGS_DIR" ]]; then
    mkdir -p "$LOGS_DIR"
fi

# =========================================================
# function:     usage
# =========================================================

usage() {
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "  -b, --build        Rebuild the Docker image after syncing"
    echo "  -r, --restart      Restart containers after syncing (implies --build)"
    echo "  -c, --create       Start containers"
    echo "  -t, --terminate    Terminate containers"
    echo "  -s, --sync-only    Sync files only, no Docker operations"
    echo "  -h, --help         Show this help message"
    echo ""
    echo "  Default (no flags): sync files and restart containers"
    echo ""
    exit 0
}

# =========================================================
# Parse arguments
# =========================================================

while [[ $# -gt 0 ]]; do
    case "$1" in
        -b|--build)     BUILD_OPT=1 ;;
        -r|--restart)   RESTART_OPT=1; BUILD_OPT=1 ;;
        -t|--terminate)   STOP_OPT=1; BUILD_OPT=0 ;;
        -c|--create)   START_OPT=1; BUILD_OPT=0 ;;
        -s|--sync-only) SYNC_ONLY_OPT=1 ;;
        -h|--help)      usage ;;
        *) log_warning "Unknown option: $1" ;;
    esac
    shift
done

# Default behaviour: sync + rebuild + restart
if [[ "$SYNC_ONLY_OPT" -eq 0 && "$BUILD_OPT" -eq 0 && "$RESTART_OPT" -eq 0 ]]; then
    BUILD_OPT=1
    RESTART_OPT=1
fi

# =========================================================
# Validate
# =========================================================

if [[ ! -d "$SERVICE_DIR" ]]; then
    fatal "Service directory not found: $SERVICE_DIR"
fi

if [[ ! -f "$COMPFILE_PATH" ]]; then
    fatal "docker-compose.yml not found: $COMPFILE_PATH"
fi

# =========================================================
# Step 1: Sync dev → service directory
# =========================================================

log_info "Syncing dev → service directory"
log_info2 "  src : $ROOT_DIR"
log_info2 "  dest: $SERVICE_DIR"

rsync -av --delete \
    --exclude='.git/' \
    --exclude='.env' \
    --exclude='*.pyc' \
    --exclude='__pycache__/' \
    --exclude='logs/' \
    --exclude='db/' \
    --exclude='db.sqlite3' \
    --exclude='/static/' \
    --exclude='*.tmp' \
    --exclude='*.tmp.png' \
    --exclude='state.json' \
    --exclude='state_old.json' \
    "$ROOT_DIR/" "$SERVICE_DIR/" >> "$LOG_FILE" 2>&1

if [[ $? -ne 0 ]]; then
    fatal "rsync failed — check $LOG_FILE for details"
fi

log_ok "Sync complete"

# =========================================================
# Step 2: Rebuild image (optional)
# =========================================================

if [[ "$SYNC_ONLY_OPT" -eq 1 ]]; then
    log_info "Sync-only mode — skipping Docker operations"
    exit 0
fi

if [[ "$BUILD_OPT" -eq 1 ]]; then
    log_info "Rebuilding Docker image..."
    cd "$ROOT_DIR" || fatal "Cannot cd to $ROOT_DIR"

    docker compose build torrents-tracker >> "$LOG_FILE" 2>&1

    if [[ $? -ne 0 ]]; then
        fatal "Docker build failed — check $LOG_FILE for details"
    fi

    log_ok "Image built successfully"
fi

# =========================================================
# Step 3: Restart containers (optional)
# =========================================================

if [[ "$RESTART_OPT" -eq 1 ]]; then
    log_info "Restarting containers..."
    cd "$ROOT_DIR" || fatal "Cannot cd to $ROOT_DIR"

    docker compose down >> "$LOG_FILE" 2>&1
    docker compose up -d >> "$LOG_FILE" 2>&1

    if [[ $? -ne 0 ]]; then
        fatal "docker compose up failed — check $LOG_FILE for details"
    fi

    log_ok "Containers are up"

    echo ""
    docker compose ps
    echo ""

elif [[ "$START_OPT" -eq 1 ]]; then
    log_info "Starting containers..."
    cd "$ROOT_DIR" || fatal "Cannot cd to $ROOT_DIR"
    docker compose down >> "$LOG_FILE" 2>&1
    docker compose up -d >> "$LOG_FILE" 2>&1

    if [[ $? -ne 0 ]]; then
        fatal "docker compose up failed — check $LOG_FILE for details"
    fi

    log_ok "Containers are up"

    echo ""
    docker compose ps
    echo ""

elif [[ "$STOP_OPT" -eq 1 ]]; then
    log_info "Stopping containers..."
    cd "$ROOT_DIR" || fatal "Cannot cd to $ROOT_DIR"

    docker compose down >> "$LOG_FILE" 2>&1

    if [[ $? -ne 0 ]]; then
        fatal "docker compose up failed — check $LOG_FILE for details"
    fi

    log_ok "Containers are up"

    echo ""
    docker compose ps
    echo ""
fi





log_ok "Deploy complete"
exit 0
