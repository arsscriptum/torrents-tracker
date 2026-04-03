#!/bin/bash

SCRIPT_PATH=$(realpath "$BASH_SOURCE")
SCRIPT_DIR=$(dirname "$SCRIPT_PATH")

tmp_root=$(pushd "$SCRIPT_DIR/.." | awk '{print $1}')
ROOT_DIR=$(eval echo "$tmp_root")
SCRIPT_PATH="$ROOT_DIR/scripts"


LOGS_DIR="$ROOT_DIR/logs"
LOG_FILE="$LOGS_DIR/build.log"

# ┌────────────────────────────────────────────────────────────────────────────────┐
# │                                                                                │
# │   logging.sh                                                                   │
# │   the logging functions are centralized and can be reused across multiple scrip│
# │   all scripts will follow the same logging format and standards                │
# ┼────────────────────────────────────────────────────────────────────────────────┼
# │   Guillaume Plante  <guillaumeplante.qc@gmail.com>                             │
# └────────────────────────────────────────────────────────────────────────────────┘


# Colors for output

##    ["black"]=30
##    ["red"]=31
##    ["green"]=32
##    ["yellow"]=33
##    ["blue"]=34
##    ["magenta"]=35
##    ["cyan"]=36
##    ["white"]=37
##    ["bright_black"]=90
##    ["bright_red"]=91
##    ["bright_green"]=92
##    ["bright_yellow"]=93
##    ["bright_blue"]=94
##    ["bright_magenta"]=95
##    ["bright_cyan"]=96
##    ["bright_white"]=97

# Background color mappings

##    ["black"]=40
##    ["red"]=41
##    ["green"]=42
##    ["yellow"]=43
##    ["blue"]=44
##    ["magenta"]=45
##    ["cyan"]=46
##    ["white"]=47
##    ["bright_black"]=100
##    ["bright_red"]=101
##    ["bright_green"]=102
##    ["bright_yellow"]=103
##    ["bright_blue"]=104
##    ["bright_magenta"]=105
##    ["bright_cyan"]=106
##    ["bright_white"]=107

bold() { echo -ne "\033[1m$1\033[0m"; }
dim() { echo -ne "\033[2m$1\033[0m"; }
italic() { echo -ne "\033[3m$1\033[0m"; }
underline() { echo -ne "\033[4m$1\033[0m"; }
blink_slow() { echo -ne "\033[5m$1\033[0m"; }
blink_rapid() { echo -ne "\033[6m$1\033[0m"; }
inverse() { echo -ne "\033[7m$1\033[0m"; }
hidden() { echo -ne "\033[8m$1\033[0m"; }
strikethrough() { echo -ne "\033[9m$1\033[0m"; }

BRED='\033[2;31m'
DIM='\033[2;36m'
ITA='\033[3;32m'
ITA2='\033[3;35m'
UNL='\033[4;33m'
BLK='\033[6;31m'
WHITE='\033[0;97m'
WHITEIT='\033[3;97m'
GRAY='\033[0;37m'
GREEN='\033[0;32m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
CYANB='\033[6;36m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color



# Check if LogCategory is defined, if not, set it to "Undefined"
: "${LogCategory:=Undefined}"

# Handy logging and error handling functions
pecho() { printf "%s\n" "$*"; }

log() { pecho "$@"; }


log_ok() {
    if [ -z "$LogJournalDisabled" ]; then
        logger --tag "$LogCategory" -p user.info "[success] $1"
    fi

    if [ -z "$LogConsoleDisabled" ]; then
        #echo -e "${GREEN}[SUCCESS] $1${NC}"
        echo -e " ✅  ${WHITE}$1${NC}"
    fi
    if [ -z "$LogFileOutDisabled" ]; then
        #echo -e "${BRED}[error] $1${NC}" >> "$LOG_FILE"
        echo -e " ✅  ${WHITE}$1${NC}" >> "$LOG_FILE"
    fi
}


log_info() {
    if [ -z "$LogJournalDisabled" ]; then
        logger --tag "$LogCategory" -p user.info "[torrentctl] $1"
    fi

    if [ -z "$LogConsoleDisabled" ]; then
        echo -e "${CYAN} 🛈${NC}   ${YELLOW}🇮🇳🇫🇴${NC}\t$1"
    fi

    if [ -z "$LogFileOutDisabled" ]; then
        echo -e "${CYAN} 🛈 ${NC}$1" >> "$LOG_FILE"
    fi
}


log_info2() {

    if [ -z "$LogConsoleDisabled" ]; then
        echo -e "${CYAN} 🛈 ${NC} ${WHITEIT}$1${NC}"
    fi

    if [ -z "$LogFileOutDisabled" ]; then
        echo "[$(date)] ${CYAN} 🛈 ${NC}$1" >> "$LOG_FILE"
    fi
}


log_notify() {
    if [ -z "$LogConsoleDisabled" ]; then
        echo -e "${MAGENTA} 🅝 ${NC} ${GRAYIT}$1${NC}"
    fi

    if [ -z "$LogFileOutDisabled" ]; then
        echo -e "${MAGENTA} 🅝 ${NC} ${GRAYIT}$1${NC}" >> "$LOG_FILE"
    fi
}

log_version() {
    if [ -z "$LogConsoleDisabled" ]; then
        echo -e "${ITA2}[version] $1${NC}"
    fi

    if [ -z "$LogJournalDisabled" ]; then
        logger --tag "$LogCategory" -p user.warning "[version] $1"
    fi

    if [ -z "$LogFileOutDisabled" ]; then
        echo -e "${ITA2}[version] $1${NC}" >> "$LOG_FILE"
    fi
}

log_test() {
    if [ -z "$LogConsoleDisabled" ]; then
        echo -e "${BLUE}  🆃🅴🆂🆃${NC}${WHITE}  $1${NC}"
        #echo -e "  🧪   ${WHITE}$1${NC}"
    fi

    if [ -z "$LogJournalDisabled" ]; then
        logger --tag "$LogCategory" -p user.warning "[test] $1"
    fi

    if [ -z "$LogFileOutDisabled" ]; then
        echo -e "${BLUE}  🆃🅴🆂🆃${NC}${WHITE}  $1${NC}" >> "$LOG_FILE"
    fi
}

log_warning() {
    if [ -z "$LogConsoleDisabled" ]; then
        echo -e " ⚠   ${YELLOW}$1${NC}"
    fi

    if [ -z "$LogJournalDisabled" ]; then
        logger --tag "$LogCategory" -p user.warning " ⚠ $1"
    fi

    if [ -z "$LogFileOutDisabled" ]; then
        echo -e " ⚠ $1" >> "$LOG_FILE"
    fi
}

log_error() {
    if [ -z "$LogConsoleDisabled" ]; then
        #echo -e "${BRED}[error] $1${NC}"
        echo -e " ❌  ${YELLOW}$1${NC}"
        
    fi

    if [ -z "$LogJournalDisabled" ]; then
        logger --tag "$LogCategory" -p user.error "[error] $1"
    fi

    if [ -z "$LogFileOutDisabled" ]; then
        #echo -e "${BRED}[error] $1${NC}" >> "$LOG_FILE"
        echo -e " ❌ $1" >> "$LOG_FILE"
    fi
}


log_outmag() {
    if [ -z "$LogConsoleDisabled" ]; then
        echo -e "${MAGENTA}$1${NC}"
    fi
}


log_t1() {
    if [ -z "$LogConsoleDisabled" ]; then
        echo -e "${TEST1}$1${NC}"
    fi

    if [ -z "$LogJournalDisabled" ]; then
        logger --tag "$LogCategory" -p user.info "$1"
    fi
}


log_t2() {
    if [ -z "$LogConsoleDisabled" ]; then
        echo -e "${TEST2}$1${NC}"
    fi

    if [ -z "$LogJournalDisabled" ]; then
        logger --tag "$LogCategory" -p user.info "$1"
    fi
}


log_t3() {
    if [ -z "$LogConsoleDisabled" ]; then
        echo -e "${TEST3}$1${NC}"
    fi

    if [ -z "$LogJournalDisabled" ]; then
        logger --tag "$LogCategory" -p user.info "$1"
    fi
}

log_bl() {
    if [ -z "$LogConsoleDisabled" ]; then
        echo -e "${BL}$1${NC}"
    fi

    if [ -z "$LogJournalDisabled" ]; then
        logger --tag "$LogCategory" -p user.info "$1"
    fi
}


log_il() {
    if [ -z "$LogConsoleDisabled" ]; then
        echo -e "${IL}$1${NC}"
    fi

    if [ -z "$LogJournalDisabled" ]; then
        logger --tag "$LogCategory" -p user.info "$1"
    fi
}

log_ul() {
    if [ -z "$LogConsoleDisabled" ]; then
        echo -e "${UL}$1${NC}"
    fi

    if [ -z "$LogJournalDisabled" ]; then
        logger --tag "$LogCategory" -p user.info "$1"
    fi
}

log_inv() {
    if [ -z "$LogConsoleDisabled" ]; then
        echo -e "${REDINV}$1${NC}"
    fi

    if [ -z "$LogJournalDisabled" ]; then
        logger --tag "$LogCategory" -p user.info "$1"
    fi
}

log_inv2() {
    if [ -z "$LogConsoleDisabled" ]; then
        echo -e "${BLUINV}$1${NC}"
    fi

    if [ -z "$LogJournalDisabled" ]; then
        logger --tag "$LogCategory" -p user.info "$1"
    fi
}


debug() { : log_info "log_info: $*" >&2; }
warn() { : log_warning "log_info: $*" >&2; }
error() { log_error "ERROR: $*" >&2; }
fatal() { log_error "FATAL $@"; exit 1; }
try() { "$@" || fatal "'$@' failed"; }

test_log() {
    log_outmag "============================================================================================="
    log_ul "Testing log function."
    log_il "Testing log_ok function."
    log_bl "Testing log_info function."
    log_warning "Testing log_warning function."
    log_t1 "test1"
    log_t2 "test2"
    log_t3 "test3"
    log_error "Testing log_error function."
    debug "Testing debug function."
    warn "Testing warn function."
    error "Testing error function."
    echo "All logging functions have been tested."
    log_outmag "============================================================================================="
}

logs_enable_all() {
    unset LogJournalDisabled
    unset LogConsoleDisabled
    unset LogFileOutDisabled
}

logs_disable_console() {
    unset LogConsoleDisabled
    export LogConsoleDisabled=1
}

logs_disable_fileout() {
    unset LogFileOutDisabled
    export LogFileOutDisabled=1
}

logs_disable_journal() {
    unset LogJournalDisabled
    export LogJournalDisabled=1
}

test_log_streams() {
    # Test 1: Normal logging (both journal and console enabled)
    unset LogJournalDisabled
    unset LogConsoleDisabled
    unset LogFileOutDisabled
    echo "Test 1: Normal logging (both journal and console enabled)"
    log_warning "This is a normal log."

    # Test 2: Console disabled
    export LogConsoleDisabled=1
    unset LogJournalDisabled
    echo "Test 2: Console disabled"
    log_warning "This log should only go to the journal."

    # Test 3: Journal disabled
    export LogJournalDisabled=1
    unset LogConsoleDisabled
    echo "Test 3: Journal disabled"
    log_warning "This log should only appear on the console."

    # Test 4: Both disabled
    export LogJournalDisabled=1
    export LogConsoleDisabled=1
    echo "Test 4: Both disabled"
    log_warning "This log should not appear anywhere."

    # Clean up environment
    unset LogJournalDisabled
    unset LogConsoleDisabled
    echo "Test completed. Environment variables cleaned up."
    log_ok "Test Completed"
}


