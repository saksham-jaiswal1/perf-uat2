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
        "${KEYSTORE_PATH}"
        "${CONF_PATH}"
        "${SCRIPTS_PATH}"
        "${TEMP_PATH}"
        "${APPS_PATH}"
        "${CERT_DIR}"
        "${API_HD_DIR}"
        "${JOB_HD_DIR}"
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

install_aeapps() {
    echo "Installing aeapps..."

    if [[ -f "$AEAPPS_SRC" ]]; then
        cp -f "$AEAPPS_SRC" "$AEAPPS_DST"
        chmod +x "$AEAPPS_DST"
    else
        echo "[WARNING] aeapps not found at $AEAPPS_SRC"
    fi
}