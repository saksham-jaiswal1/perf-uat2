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

  echo "[INFO] Downloading s3://${S3_DEPLOY_BUCKET}/$S3_KEY to ${ZIP_PATH}"
  aws s3 cp "s3://${S3_DEPLOY_BUCKET}/$S3_KEY" "${ZIP_PATH}" --no-progress

  echo "[INFO] Download complete Path :- ${ZIP_PATH}"
}

fetch_secrets() {
    echo "Fetching secrets from AWS..."
    secret=$(aws secretsmanager get-secret-value --region "$REGION" --secret-id "$smName" --query SecretString --output text) || exit 1
    keystorePass=$(echo "$secret" | jq -r '.extra.keystorePass')
    storePass=$(echo "$secret" | jq -r '.extra.trustStorePass')
    cacertPass=$(echo "$secret" | jq -r '.extra.cacertPass')
}

extract_api_zip() {
    echo "Extracting API build..."
    [[ -f "$ZIP_PATH" ]] || { echo "API zip not found at $zip_file"; exit 1; }
    unzip -qq "$ZIP_PATH" -d "$INIT_APPS_PATH"
}

copy_env_configs() {
    echo "Copying ENV configs..."

    if [[ -d scripts/configs ]]; then
        cp scripts/configs/* "${APPS_PATH}/conf/"
    fi

    if [[ -e "${Branch12}" ]]; then
        cp scripts/systems/*.conf "${APPS_PATH}/conf/"
    elif [[ -e "${Branch11}" ]]; then
        cp scripts/systems/default_env.conf "${APPS_PATH}/conf/"
        cp scripts/systems/keystore_env.conf "${APPS_PATH}/conf/"
    else
        cp scripts/systems/default_env.conf "${APPS_PATH}/conf/"
    fi
}



update_environment_conf() {
    local env_file="${APPS_PATH}/conf/environment.conf"

    # Exit early if the original file doesn't exist
    [[ -f "${env_file}.original" ]] || return

    # Restore the original environment config
    cp "${env_file}.original" "$env_file"
    sed -i 's/\r$//' "$env_file"

    # Append include statements based on available files
    if [[ -e "${Branch12}" || -e "${Branch11}" ]]; then
        cat <<EOF >> "$env_file"

include "default_env"
include "override_env"
include "keystore_env"
EOF
    else
        cat <<EOF >> "$env_file"

include "default_env"
include "override_env"
include "sso"
EOF
    fi
}

remove_keystore_secret() {
    echo "🔍 Checking for PLAY_HTTP_SECRET_KEY in environment files..."

    if grep -q '^PLAY_HTTP_SECRET_KEY=".*"$' "${APPS_PATH}/conf/environment.conf" || \
       grep -q '^PLAY_HTTP_SECRET_KEY=".*"$' "${APPS_PATH}/conf/environment.conf.original"; then

        echo "🔒 Found secret key entry. Removing..."
        sed -i '/^PLAY_HTTP_SECRET_KEY=".*"$/d' "${APPS_PATH}/conf/environment.conf"
        sed -i '/^PLAY_HTTP_SECRET_KEY=".*"$/d' "${APPS_PATH}/conf/environment.conf.original"
        echo "✅ Secret key removed."
    else
        echo "ℹ️  No PLAY_HTTP_SECRET_KEY entry found. Exiting function."
        return
    fi
}

setup_keystore() {
    # Skip if both Branch12 and Branch11 are not present (Branch10 case)
    if [[ ! -e "${Branch12}" && ! -e "${Branch11}" ]]; then
        echo "Keystore setup skipped due to Branch10 (this doesn't require keystore)"
        return
    fi

    echo "Keystore setup Start"

    # Function to inject keys into the keystore (New keystore setup)
    new_keystore_setup() {
        printf "%s" "$keystorePass" > "${KEYSTORE_KEY_PATH}"

        echo "$secret" | jq -c '.keystore[]' | while read -r item; do
            key=$(echo "$item" | jq -r 'to_entries[0].key')
            val=$(echo "$item" | jq -r 'to_entries[0].value')
            echo "Running for $key"

            cd "${APPS_PATH}/lib" || exit 1
            java -cp "./*" \
                -Dlog4j.configurationFile=../conf/log4j2.xml \
                -Dcrypto.configurationFile=../conf/keystore.conf \
                com.alnt.cryptoutil.Main key_upsert "$key" "$val" || exit 1
        done

        rm -f "${KEYSTORE_KEY_PATH}"
    }

    # Function for legacy keystore setup (Old keystore setup)
    old_keystore_setup() {

        echo "$secret" | jq -c '.keystore[]' | while read -r item; do
            key=$(echo "$item" | jq -r 'to_entries[0].key')
            val=$(echo "$item" | jq -r 'to_entries[0].value')
            echo "Running for $key"

            cd "${APPS_PATH}/lib" || exit 1
            java -jar keystore-0.0.1-SNAPSHOT.jar \
                "$keystoreFile" \
                "$keystorePass" \
                "$val" "$key" || exit 1
        done
        echo "Keystore setup for branch 11 completed."
    }

    # Fetch secrets from AWS Secrets Manager
    secret=$(aws secretsmanager get-secret-value --region "$REGION" --secret-id "$smName" --query SecretString --output text) || {
        echo "[ERROR] Failed to get secret"
        exit 1
    }

    keystorePass=$(echo "$secret" | jq -r '.extra.keystorePass')
    [ -z "$keystorePass" ] && echo "[ERROR] Missing keystorePass!" && exit 1

    # Create or reuse keystore based on branch type
    if [[ -e "${Branch12}" ]]; then
        # AES-based keystore (New)
        if [ -f "$keystoreFile" ]; then
            if [ "$KEYSTORE_FORCE_CREATE" == "Y" ]; then
                echo "Removing old keystore for branch 12 and creating new one for branch 12..."
                rm -f "$keystoreFile"
                keytool -genseckey -keyalg AES -keysize 256 \
                        -keystore "$keystoreFile" -storetype PKCS12 \
                        -storepass "$keystorePass" -keypass "$keystorePass"
                new_keystore_setup
            else
                echo "Keystore for branch 12 already present. Skipping creation."
            fi
        else
            echo "Creating new keystore of branch 12..."
            keytool -genseckey -keyalg AES -keysize 256 \
                    -keystore "$keystoreFile" -storetype PKCS12 \
                    -storepass "$keystorePass" -keypass "$keystorePass"
            new_keystore_setup
        fi

    elif [[ -e "${Branch11}" ]]; then
        # RSA-based keystore (Old)
        if [ -f "$keystoreFile" ]; then
            if [ "$KEYSTORE_FORCE_CREATE" == "Y" ]; then
                echo "Removing old keystore for branch 11 and creating new one for branch 11..."
                rm -f "$keystoreFile"
                keytool -genkeypair -dname "cn=Alert Enterprise, ou=Java, o=Oracle, c=US" -alias alert \
                        -keystore "$keystoreFile" \
                        -storepass "$keystorePass" -keypass "$keystorePass"
                old_keystore_setup
            else
                echo "Keystore for branch 11 already present. Skipping creation."
            fi
        else
            echo "Creating new keystore for branch 11..."
            keytool -genkeypair -dname "cn=Alert Enterprise, ou=Java, o=Oracle, c=US" -alias alert \
                    -keystore "$keystoreFile" \
                    -storepass "$keystorePass" -keypass "$keystorePass"
            old_keystore_setup
        fi
    fi

    echo "Keystore setup completed."
}


otherKeys() {
    echo "[INFO] Fetching secrets..."
    secret=$(aws secretsmanager get-secret-value --region "$REGION" --secret-id "$smName" --query SecretString --output text) || exit 1
    len=$(echo "$secret" | jq '.otherKeys | length')

    for ((i=0; i<len; i++)); do
        type=$(echo "$secret" | jq -r ".otherKeys[$i].type")
        alias=$(echo "$secret" | jq -r ".otherKeys[$i].alias")
        pkey=$(echo "$secret" | jq -r ".otherKeys[$i].privateKey")
        pass=$(echo "$secret" | jq -r ".extra.keystorePass")

        [[ -z "$pkey" || -z "$alias" || -z "$type" || -z "$pass" ]] && { echo "[WARN] Missing data for index $i"; continue; }

        echo "$pkey" > k.pem
        [[ "$type" != "rsa" ]] && { echo "[ERROR] Unsupported type: $type"; rm -f k.pem; continue; }
        openssl req -new -x509 -key k.pem -out c.pem -days 365 -subj "/C=IN/ST=Chandigarh/L=Chandigarh/O=Alert/OU=DevOps/CN=alerthsc.com"
        openssl pkcs12 -export -inkey k.pem -in c.pem -name "$alias" -out ks.p12 -passout "pass:$pass"
        keytool -importkeystore -srckeystore ks.p12 -srcstoretype PKCS12 -destkeystore "$keystoreFile" -srcalias "$alias" -destalias "$alias" -srcstorepass "$pass" -deststorepass "$pass" -noprompt
        rm -f k.pem c.pem ks.p12
        echo "[INFO] Done: $alias"
    done
}



install_certs() {
    echo "[INFO] Downloading certificates from s3://${S3_DEPLOY_BUCKET}/${CERT_DIR}"
    aws s3 cp "s3://${S3_DEPLOY_BUCKET}/certs/" "${CERT_DIR}/" --recursive

    for cert_file in "$CERT_DIR"/*; do
        # Skip .p12 files, README.md, and directories
        if [[ -d "$cert_file" || "$cert_file" == *.p12 || "$(basename "$cert_file")" == "README.md" ]]; then
            continue
        fi

        cert_alias=$(basename "$cert_file")

        # Import into cacerts if alias not already present
        if ! keytool -list -keystore "$CACERTS_PATH" -storepass "$cacertPass" -alias "$cert_alias" >/dev/null 2>&1; then
            echo "[INFO] Importing $cert_alias into cacerts"
            keytool -import -alias "$cert_alias" -keystore "$CACERTS_PATH" -file "$cert_file" -storepass "$cacertPass" -noprompt
        fi

        # Import into truststore if alias not already present
        if ! keytool -list -keystore "$TRUSTSTORE_PATH" -storepass "$storePass" -alias "$cert_alias" >/dev/null 2>&1; then
            echo "[INFO] Importing $cert_alias into truststore"
            keytool -import -alias "$cert_alias" -keystore "$TRUSTSTORE_PATH" -file "$cert_file" -storepass "$storePass" -noprompt
        fi
    done
}


separateKeystore() {
    echo "[INFO] Creating separate keystore(s)..."
    len=$(echo "$secret" | jq '.separateKeystore | length')

    for ((i=0; i<len; i++)); do
        fpath=$(echo "$secret" | jq -r ".separateKeystore[$i].filePath")
        pass=$(echo "$secret" | jq -r ".separateKeystore[$i].password")
        alias=$(echo "$secret" | jq -r ".separateKeystore[$i].alias")
        pkey=$(echo "$secret" | jq -r ".separateKeystore[$i].privateKey")
        cert=$(echo "$secret" | jq -r ".separateKeystore[$i].certificateName")

        [[ -z "$pkey" || -z "$fpath" || -z "$pass" || -z "$alias" || -z "$cert" ]] && { 
            echo "[WARN] Skipping index $i — missing data"; continue; 
        }
        dir=$(dirname "$fpath")
        [[ ! -d "$dir" ]] && { echo "[INFO] Creating directory: $dir"; mkdir -p "$dir"; }

        echo "$pkey" > k.pem
        openssl pkcs12 -export -out "$fpath" -inkey k.pem -in "$CERT_DIR/$cert" -name "$alias" -password pass:"$pass" \
        && echo "✅ Created: $fpath" || echo "❌ Failed: $fpath"
        rm -f k.pem
    done
}

run_others_after() {
        chmod +x scripts/others_after.sh
        bash -x scripts/others_after.sh
}

sedFiles() {
    echo "Running sed command on override_env.conf"
    
    sed -i "s/{DOMAIN}/${DOMAIN_NAME}/g" "${APPS_PATH}/conf/override_env.conf"
    sed -i "s/{SUBDOMAIN}/${SUB_DOMAIN_NAME}/g" "${APPS_PATH}/conf/override_env.conf"

    echo "Running sed command to replace {AEKEYSTOREFILE} with keystoreFile in both config files"

    sed -i "s|{AEKEYSTOREFILE}|${keystoreFile}|g" "${APPS_PATH}/conf/keystore_env.conf"
    sed -i "s|{AEKEYSTOREFILE}|${keystoreFile}|g" "${APPS_PATH}/conf/keystore.conf"

    echo "Running sed command to replace {AEKEYSTOREPASSWD} with KEYSTORE_KEY_PATH  in both keystore.conf"
    sed -i "s|{AEKEYSTOREPASSWD}|${KEYSTORE_KEY_PATH}|g" "${APPS_PATH}/conf/keystore.conf"

}       

main() {
    download_and_extract_zip
    fetch_secrets
    extract_api_zip
    copy_env_configs
    update_environment_conf
    remove_keystore_secret
    sedFiles
    setup_keystore
    otherKeys
    install_certs
    separateKeystore
    run_others_after
}

main
