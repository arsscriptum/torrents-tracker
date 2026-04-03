#!/bin/bash

#+--------------------------------------------------------------------------------+
#|                                                                                |
#|   run.sh                                                                       |
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
STOP_OPT=0
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
TMP_ENV_FILE="$ROOT_DIR/.env.aes"
DATA_DIR="$ROOT_DIR/data"
CODED_FILE="$DATA_DIR/env.aes"

aescrypt -e "$ENV_FILE"
mv "$TMP_ENV_FILE" "$CODED_FILE"
