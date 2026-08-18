#!/bin/bash

#+--------------------------------------------------------------------------------+
#|                                                                                |
#|   start-tracker.sh                                                             |
#|                                                                                |
#+--------------------------------------------------------------------------------+
#|   Guillaume Plante <codegp@icloud.com>                                         |
#|   Code licensed under the GNU GPL v3.0. See the LICENSE file for details.      |
#+--------------------------------------------------------------------------------+
#
#   Brings the torrents-tracker stack online and verifies it is healthy.
#
#   Steps:
#     1. Pre-flight: docker available, compose file present, env file present
#     2. Disk space guard: abort if data partition above MAX_DISK_PCT
#     3. docker compose up -d
#     4. Wait until VPN container is "Up" and reports a non-empty external IP
#        from the expected country (default NL)
#     5. Wait until tracker app responds on port 7070
#     6. Stability re-check after STABLE_WAIT seconds
#
#   Usage:
#     scripts/start-tracker.sh [-f] [-h]
#
#     -f, --force      Skip disk-space guard
#     -h, --help       Show this help
#
#   Exit codes:
#     0  success      stack is up, VPN ok, app ok
#     1  bad usage / missing prerequisites
#     2  disk space exceeded
#     3  docker compose failed
#     4  vpn never came up / wrong exit country
#     5  tracker never responded
#     6  stack went unstable during stability re-check
#

SCRIPT_PATH=$(realpath "$BASH_SOURCE")
SCRIPT_DIR=$(dirname "$SCRIPT_PATH")
ROOT_DIR=$(realpath "$SCRIPT_DIR/..")

ENV_FILE="$ROOT_DIR/.env"
LOGGING="$SCRIPT_DIR/logging.sh"
LOGS_DIR="$ROOT_DIR/logs"
LOG_FILE="$LOGS_DIR/start-tracker.log"
COMPFILE_PATH="$ROOT_DIR/docker-compose.yml"

# Container names from docker-compose.yml
APP_CONTAINER="torrents-tracker"
VPN_CONTAINER="transmissionvpn"

# Tunables
MAX_DISK_PCT="${MAX_DISK_PCT:-92}"           # abort if /mnt/datassd usage above this
DATA_MOUNT="${DATA_MOUNT:-/mnt/plexdata}"
APP_URL="${APP_URL:-http://127.0.0.1:7070/tracker/}"
EXPECTED_COUNTRY="${EXPECTED_COUNTRY:-CA}"
WAIT_VPN_TIMEOUT="${WAIT_VPN_TIMEOUT:-180}"  # seconds to wait for VPN tunnel to be up
WAIT_APP_TIMEOUT="${WAIT_APP_TIMEOUT:-60}"   # seconds to wait for app to respond
STABLE_WAIT="${STABLE_WAIT:-15}"             # post-start stability window

LogCategory="start-tracker"

FORCE_OPT=0

# =========================================================
# Bootstrap
# =========================================================

if [[ ! -f "$LOGGING" ]]; then
    echo "[error] missing logging.sh @ \"$LOGGING\"!" >&2
    exit 1
fi
# shellcheck source=logging.sh
source "$LOGGING"

if [[ ! -d "$LOGS_DIR" ]]; then
    mkdir -p "$LOGS_DIR"
fi

# =========================================================
# Functions
# =========================================================

usage() {
    cat <<EOF

Usage: $0 [options]

  -f, --force        Skip disk-space guard (use with care)
  -h, --help         Show this help

Environment overrides:
  MAX_DISK_PCT=$MAX_DISK_PCT     Abort if $DATA_MOUNT usage above this
  DATA_MOUNT=$DATA_MOUNT
  APP_URL=$APP_URL
  EXPECTED_COUNTRY=$EXPECTED_COUNTRY
  WAIT_VPN_TIMEOUT=$WAIT_VPN_TIMEOUT
  WAIT_APP_TIMEOUT=$WAIT_APP_TIMEOUT
  STABLE_WAIT=$STABLE_WAIT

EOF
    exit 0
}

require_cmd() {
    if ! command -v "$1" >/dev/null 2>&1; then
        log_error "required command not found: $1"
        exit 1
    fi
}

container_status() {
    # Returns the docker status string, or empty if container does not exist
    docker inspect -f '{{.State.Status}}' "$1" 2>/dev/null || true
}

container_running() {
    [[ "$(container_status "$1")" == "running" ]]
}

# =========================================================
# Parse arguments
# =========================================================

while [[ $# -gt 0 ]]; do
    case "$1" in
        -f|--force) FORCE_OPT=1 ;;
        -h|--help)  usage ;;
        *) log_warning "Unknown option: $1"; usage ;;
    esac
    shift
done

# =========================================================
# Pre-flight checks
# =========================================================

log_info "Pre-flight checks"

require_cmd docker
require_cmd curl
require_cmd awk

if ! docker compose version >/dev/null 2>&1; then
    log_error "'docker compose' plugin is not available"
    exit 1
fi

if [[ ! -f "$COMPFILE_PATH" ]]; then
    fatal "docker-compose.yml not found: $COMPFILE_PATH"
fi

if [[ ! -f "$ENV_FILE" ]]; then
    fatal ".env not found: $ENV_FILE"
fi
# shellcheck disable=SC1090
source "$ENV_FILE"

if [[ -z "${OPENVPN_USERNAME:-}" || -z "${OPENVPN_PASSWORD:-}" ]]; then
    fatal "OPENVPN_USERNAME / OPENVPN_PASSWORD missing from $ENV_FILE"
fi

log_ok "Pre-flight ok"

# =========================================================
# Disk space guard
# =========================================================

if [[ ! -d "$DATA_MOUNT" ]]; then
    log_warning "Data mount $DATA_MOUNT does not exist — skipping disk guard"
else
    used_pct=$(df --output=pcent "$DATA_MOUNT" | tail -1 | tr -dc '0-9')
    avail_h=$(df -h --output=avail "$DATA_MOUNT" | tail -1 | tr -d ' ')
    log_info2 "Disk usage at $DATA_MOUNT: ${used_pct}% used, ${avail_h} free (limit ${MAX_DISK_PCT}%)"

    if [[ -z "$used_pct" ]]; then
        log_warning "Could not parse disk usage — continuing"
    elif (( used_pct >= MAX_DISK_PCT )); then
        if (( FORCE_OPT == 1 )); then
            log_warning "Disk above ${MAX_DISK_PCT}% but --force given, continuing anyway"
        else
            log_error "Disk usage ${used_pct}% on $DATA_MOUNT exceeds limit ${MAX_DISK_PCT}%"
            log_error "Free space before starting, or rerun with --force"
            exit 2
        fi
    else
        log_ok "Disk space ok"
    fi
fi

# =========================================================
# Bring the stack up
# =========================================================

log_info "Starting docker compose stack"
cd "$ROOT_DIR" || fatal "cannot cd to $ROOT_DIR"

if ! docker compose --env-file "$ENV_FILE" up -d >> "$LOG_FILE" 2>&1; then
    log_error "docker compose up failed — see $LOG_FILE"
    exit 3
fi
log_ok "docker compose up issued"

# =========================================================
# Wait for VPN container to be running and on the right exit
# =========================================================

log_info "Waiting for VPN container '$VPN_CONTAINER' tunnel to come up (timeout ${WAIT_VPN_TIMEOUT}s, expecting country=$EXPECTED_COUNTRY)"

deadline=$(( SECONDS + WAIT_VPN_TIMEOUT ))
vpn_country=""
vpn_ip=""
last_logged=""
while (( SECONDS < deadline )); do
    if container_running "$VPN_CONTAINER"; then
        # Run curl from inside the VPN container — that container's network
        # namespace is what the app shares, so this is the real exit IP.
        # Short curl timeout so we don't block the polling loop.
        ipjson=$(docker exec "$VPN_CONTAINER" sh -c \
            'curl -fsS --max-time 5 https://ipinfo.io/json 2>/dev/null' 2>/dev/null || true)
        if [[ -n "$ipjson" ]]; then
            vpn_country=$(printf '%s' "$ipjson" \
                | awk -F'"' '/"country"/ {print $4; exit}')
            vpn_ip=$(printf '%s' "$ipjson" \
                | awk -F'"' '/"ip"/ {print $4; exit}')
            # Only log when the seen ip changes, to keep the output readable
            if [[ "$vpn_ip" != "$last_logged" ]]; then
                log_info2 "VPN currently reports ip=$vpn_ip country=$vpn_country"
                last_logged="$vpn_ip"
            fi
            if [[ "$vpn_country" == "$EXPECTED_COUNTRY" ]]; then
                break
            fi
        fi
    fi
    sleep 3
done

if [[ "$vpn_country" != "$EXPECTED_COUNTRY" ]]; then
    if [[ -z "$vpn_country" ]]; then
        log_error "VPN container never reported an external IP within ${WAIT_VPN_TIMEOUT}s"
    else
        log_error "VPN exit country never reached '$EXPECTED_COUNTRY' within ${WAIT_VPN_TIMEOUT}s (last seen: $vpn_country / $vpn_ip)"
        log_error "Tunnel did not come up — leaking host IP, app stays unreachable"
    fi
    docker logs --tail 40 "$VPN_CONTAINER" >> "$LOG_FILE" 2>&1 || true
    exit 4
fi

log_ok "VPN tunnel up — exiting via $vpn_country (ip=$vpn_ip)"

# =========================================================
# Repair stale app namespace if VPN was recreated
# =========================================================
# When transmissionvpn is recreated but torrents-tracker was already up,
# the app keeps a 'container:<old-vpn-id>' NetworkMode pointing at the
# now-gone VPN container. The app process keeps running but its published
# ports are unreachable. Detect that case by comparing IDs and force-recreate
# the app so it joins the new VPN namespace.

vpn_id=$(docker inspect -f '{{.Id}}' "$VPN_CONTAINER" 2>/dev/null || true)
app_netmode=$(docker inspect -f '{{.HostConfig.NetworkMode}}' "$APP_CONTAINER" 2>/dev/null || true)
app_linked_id="${app_netmode#container:}"

if [[ -n "$vpn_id" && -n "$app_linked_id" && "$vpn_id" != "$app_linked_id" ]]; then
    log_warning "App container is linked to a stale VPN namespace — recreating $APP_CONTAINER"
    if ! docker compose --env-file "$ENV_FILE" up -d --force-recreate "$APP_CONTAINER" >> "$LOG_FILE" 2>&1; then
        log_error "Failed to recreate $APP_CONTAINER — see $LOG_FILE"
        exit 3
    fi
    log_ok "App container recreated against current VPN namespace"
fi

# =========================================================
# Wait for the tracker app to respond
# =========================================================

log_info "Waiting for tracker app at $APP_URL (timeout ${WAIT_APP_TIMEOUT}s)"

deadline=$(( SECONDS + WAIT_APP_TIMEOUT ))
app_ok=0
http_code=""
while (( SECONDS < deadline )); do
    if container_running "$APP_CONTAINER"; then
        http_code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "$APP_URL" || true)
        # Anything 2xx/3xx is fine; Django often returns 302 to login etc.
        if [[ "$http_code" =~ ^(2|3)[0-9][0-9]$ ]]; then
            app_ok=1
            break
        fi
    fi
    sleep 2
done

if (( app_ok != 1 )); then
    log_error "Tracker app did not respond at $APP_URL within ${WAIT_APP_TIMEOUT}s (last code: ${http_code:-none})"
    docker logs --tail 30 "$APP_CONTAINER" >> "$LOG_FILE" 2>&1 || true
    exit 5
fi
log_ok "Tracker app responding (HTTP $http_code)"

# =========================================================
# Stability re-check
# =========================================================

log_info "Stability window: sleeping ${STABLE_WAIT}s then re-checking"
sleep "$STABLE_WAIT"

if ! container_running "$VPN_CONTAINER"; then
    log_error "VPN container is no longer running after stability window"
    exit 6
fi
if ! container_running "$APP_CONTAINER"; then
    log_error "App container is no longer running after stability window"
    exit 6
fi

http_code2=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "$APP_URL" || true)
if ! [[ "$http_code2" =~ ^(2|3)[0-9][0-9]$ ]]; then
    log_error "Tracker app stopped responding during stability window (HTTP ${http_code2:-none})"
    exit 6
fi

log_ok "Stack is stable"

# =========================================================
# Summary
# =========================================================

echo ""
docker compose ps
echo ""
log_ok "torrents-tracker is up — VPN=$vpn_country  app=HTTP $http_code2  disk=${used_pct:-?}%/$MAX_DISK_PCT%"
exit 0
