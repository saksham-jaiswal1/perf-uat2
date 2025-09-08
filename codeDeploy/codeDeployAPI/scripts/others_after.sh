#!/bin/bash
SCRIPT_PATH="$(readlink -f "$0")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"
cd ${SCRIPT_DIR}/../
source scripts/common.sh
load_env

if [[ "$CW_AGENT" == true ]]; then
    if [[ -f "$CW_CONFIG_FILE" ]]; then
        #sed -i "s/\"log_group_name\": \".*\"/\"log_group_name\": \"${ENV}-${CLIENT}-api\"/" $CW_CONFIG_FILE
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
