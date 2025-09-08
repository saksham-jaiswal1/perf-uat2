#!/bin/bash
SCRIPT_PATH="$(readlink -f "$0")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"
cd ${SCRIPT_DIR}/../
source scripts/common.sh
load_env
create_dirs
install_aeapps
ensure_tools
cp scripts/systems/.env ${APP_PATH}


update_aeapps() {
    local file="/usr/bin/aeapps"
    local old="alert-api-server-1.0"
    local new="alert-server-1.0"

    if [[ "$Branch10" != "Y" ]]; then
        echo "🚫 Skipping update_aeapps: Branch10 is not 'Y'"
        return
    fi

    echo "🔍 Running updates in ${file}..."

    if grep -q "${old}" "$file"; then
        echo "🔧 Updating '${old}' to '${new}'..."
        sed -i "s/${old}/${new}/g" "$file"
    else
        echo "ℹ️  '${old}' not found. Skipping that replacement."
    fi

    if grep -q "^#PLAY_HTTP_SECRET_KEY_VALUE" "$file"; then
        echo "🔧 Uncommenting '#PLAY_HTTP_SECRET_KEY_VALUE'..."
        sed -i "s/^#PLAY_HTTP_SECRET_KEY_VALUE/PLAY_HTTP_SECRET_KEY_VALUE/" "$file"
    else
        echo "ℹ️  '#PLAY_HTTP_SECRET_KEY_VALUE' not found. Skipping that replacement."
    fi

    echo "✅ update_aeapps completed."
}


update_aeapps

if [[ -f $ZIP_PATH ]]; then
rm -rf ${ZIP_PATH}
fi

if [ -d "${APP_PATH}" ]; then

    if [ -e "${APP_PATH}/bkp_2" ]; then
        ls -ld "${APP_PATH}/bkp_2"
        rm -rf "${APP_PATH}/bkp_2"
        echo "Removed bkp2"
        ls -ls "${APP_PATH}"
    fi
    if [ -e "${APP_PATH}/bkp_1" ]; then
        ls -ld "${APP_PATH}/bkp_1"
        mv "${APP_PATH}/bkp_1" "${APP_PATH}/bkp_2"
        echo "Moved bkp1 to bkp2"
        ls -ls "${APP_PATH}/"
    fi

        echo "creating directory bkp1"
        mkdir -p "${APP_PATH}/bkp_1"
        ls -l "${APP_PATH}"
        mv "${APPS_PATH}" "${APP_PATH}/bkp_1/"
        ls -l "${APP_PATH}/apps"
        echo "New Build deploying to apps"
fi
