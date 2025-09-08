#!/bin/bash
SCRIPT_PATH="$(readlink -f "$0")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"
cd ${SCRIPT_DIR}/../
source scripts/common.sh
load_env

echo "Nginx not required to stop!"

