#!/bin/bash
SCRIPT_PATH="$(readlink -f "$0")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"
cd ${SCRIPT_DIR}/../
source scripts/common.sh
load_env
ensure_tools

download_and_extract_zip() {
  echo "[INFO] Checking if directory exists: $DEST_DIR"
  [[ -d "$DEST_DIR" ]] && echo "[INFO] Directory $DEST_DIR already exists. Skipping creation." || { echo "[INFO] Creating directory: $DEST_DIR"; mkdir -p "$DEST_DIR"; }

  echo "[INFO] Downloading s3://$S3_DEPLOY_BUCKET/$S3_KEY to ${ZIP_PATH}"
  aws s3 cp "s3://$S3_DEPLOY_BUCKET/$S3_KEY" "${ZIP_PATH}" --no-progress

  echo "[INFO] Download complete Path :- ${ZIP_PATH}"
}

extract_ui_zip() {
    echo "Extracting API build..."
    [[ -f "$ZIP_PATH" ]] || { echo "API zip not found at $zip_file"; exit 1; }
    unzip -qq "$ZIP_PATH" -d "$INIT_APPS_PATH"
}

run_others_after() {
        chmod +x scripts/others_after.sh
        bash -x scripts/others_after.sh
}

main() {
    download_and_extract_zip
    extract_ui_zip
    run_others_after
}

main
