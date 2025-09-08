#!/bin/bash

SCRIPT_PATH="$(readlink -f "$0")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"
cd ${SCRIPT_DIR}/../
source scripts/common.sh
load_env

while ! netstat -tuln | grep ":$port\s" > /dev/null 2>&1; do
    if ((retry_count >= max_retries)); then
        echo "❌ Port $port not available after $((max_retries * 30))s"
        exit 1
    fi
    echo "Waiting for port $port... (Attempt $((++retry_count)))"
    sleep 30
done

echo "✅ Port $port is now available."