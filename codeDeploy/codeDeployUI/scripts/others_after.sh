#!/bin/bash
SCRIPT_PATH="$(readlink -f "$0")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"
cd ${SCRIPT_DIR}/../
source scripts/common.sh
load_env

if [[ "$CW_AGENT" == true ]]; then
    if [[ -f "$CW_CONFIG_FILE" ]]; then
        sed -i "s/\"log_group_name\": \".*\"/\"log_group_name\": \"${ENV}-${CLIENT}-ui\"/" $CW_CONFIG_FILE
        echo "Copying CloudWatch cw_config.json to $CW_PATH/config.json"
        cp "$CW_CONFIG_FILE" "$CW_PATH/config.json"

        sudo amazon-linux-extras install collectd -y
        echo "Reconfiguring CloudWatch Agent"
        sudo "${CW_PATH}/amazon-cloudwatch-agent-ctl" -a fetch-config -m ec2 -c file:"${CW_PATH}/config.json" -s

        echo "Restarting CloudWatch Agent"
        sudo systemctl restart amazon-cloudwatch-agent
    else
        echo "[WARN] CloudWatch config.json not found at: $CW_CONFIG_FILE"
    fi
fi


if [[ "$NGINX_UPDATE" == true ]]; then
    echo "Nginx changes enabled."

    echo "Copying nginx config files to ${ALERT_NGINX_PATH}"
    yes | cp -rf scripts/configs/. "${ALERT_NGINX_PATH}"
    sed -i "s|ENVURL|${ENV_URL}|g" "${ALERT_NGINX_PATH}/conf.d/alert.conf"

    echo "Restarting Nginx..."
    sudo systemctl restart nginx
else
    echo "Nginx changes disabled."
fi