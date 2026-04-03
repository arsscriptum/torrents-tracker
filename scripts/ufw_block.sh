#!/bin/bash

# ┌────────────────────────────────────────────────────────────────────────────────┐
# │                                                                                │
# │   ufw_block.sh                                                                 │
# │   block a list of hosts using ufw                                              │
# │                                                                                │
# ┼────────────────────────────────────────────────────────────────────────────────┼
# │   Guillaume Plante  <guillaumeplante.qc@gmail.com>                             │
# └────────────────────────────────────────────────────────────────────────────────┘


# Colors for output
UL='\033[4;93m'
IL='\033[3;91m'
BL='\033[6;94m'
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

LogCategory=firewall

# handy logging and error handling functions
pecho() { printf %s\\n "$*"; }

log() { pecho "$@"; }

# Verbose output function
log_info() {
    echo -e "${CYAN}[INFO] $1${NC}"
    logger --tag $LogCategory -p user.info "[INFO] $1"
}

log_ul() {
    echo -e "${UL}$1${NC}"
    logger --tag $LogCategory -p user.info "$1"
}

log_bl() {
    echo -e "${BL}$1${NC}"
    logger --tag $LogCategory -p user.info "$1"
}

log_il() {
    echo -e "${IL}$1${NC}"
    logger --tag $LogCategory -p user.info "$1"
}



log_warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
    logger --tag $LogCategory -p user.warning "[WARNING] $1"
}
log_error() {
    echo -e "${RED}[ERROR] $1${NC}"
    logger --tag $LogCategory -p user.error "[ERROR] $1"
}
debug() { : log_info "DEBUG: $@" >&2; }
error() { log_info "ERROR: $@" >&2; }
fatal() { log_error "$@"; exit 1; }
try() { "$@" || fatal "'$@' failed"; }
usage_fatal() { usage >&2; pecho "" >&2; fatal "$@"; }


log_il "\nufw_block.sh - blocking ads servers\n"

# List of hosts to block
hosts=(
    "assets.bwbx.io"
    "bwbx.io"
    "securepubads.g.doubleclick.net"
    "g.doubleclick.net"
    "doubleclick.net"
    "vi.ml314.com"
    "ml314.com"
    "onautcatholi.xyz"
    "torrindex.net"
    "exdynsrv.com"
    "ricewaterhou.xyz"
    "js.wpadmngr.com"
    "italarizege.xyz"
    "abservinean.com"
    "a.exdynsrv.com"
    "a.exosrv.com"
    "cdn.engine.spotscenered.info"
    "syndication.exdynsrv.com"
    "d1n3aexzs37q4s.cloudfront.net"
    "iconcardinal.com"
    "cipledecline.buzz"
    "www.viled.cfd"
)

# Function to resolve hostnames to IP addresses and block traffic using ufw
block_host() {
    host=$1
    # Resolve the hostname to an IP address
    ip=$(dig +short $host | tail -n 1)

    if [ -z "$ip" ]; then
        log_warning "Unable to resolve IP for $host"
    else
        # Block incoming and outgoing traffic to the resolved IP
        log_info "Blocking IP: $ip ($host)"
 #       sudo ufw deny in from $ip
#        sudo ufw deny out to $ip
    fi
}

# Iterate over each host and block it
for host in "${hosts[@]}"; do
    block_host "$host"
done

log_info "reloading ufw"
# Reload UFW to apply changes
#sudo ufw reload
