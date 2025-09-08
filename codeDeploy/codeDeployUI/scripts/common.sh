#!/bin/bash
pwd
load_env() {
    ENV_FILE="scripts/systems/.env"
    if [[ -f "$ENV_FILE" ]]; then
        source "$ENV_FILE"
    else
        echo "[ERROR] .env file not found at $ENV_FILE"
        exit 1
    fi
}

ensure_tools() {
    command -v jq >/dev/null || sudo yum install -y jq
    command -v aws >/dev/null || { echo "[ERROR] AWS CLI not installed"; exit 1; }
}

create_dirs() {
    echo "Validating and creating base directories..."

    dirs=(
        "${INIT_APPS_PATH}"
        "${SCRIPTS_PATH}"
        "${TEMP_PATH}"
        "${APPS_PATH}"
    )

    for dir in "${dirs[@]}"; do
        if [ -d "$dir" ]; then
            echo "Directory already exists: $dir"
        else
            echo "Creating directory: $dir"
            mkdir -p "$dir"
        fi
    done
}

