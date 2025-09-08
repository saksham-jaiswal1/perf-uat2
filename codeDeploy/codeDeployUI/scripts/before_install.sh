#!/bin/bash
SCRIPT_PATH="$(readlink -f "$0")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"
cd ${SCRIPT_DIR}/../
source scripts/common.sh
load_env
create_dirs
ensure_tools
cp scripts/systems/.env ${APP_PATH}

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
