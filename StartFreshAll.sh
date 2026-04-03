#!/bin/bash

PROJECT_PATH=/home/gp/dev/torrents-tracker
# Step 1: Get the current path
CURRENT_PATH=$(pwd)
echo "Current path: $CURRENT_PATH"
cd $PROJECT_PATH || { echo "Error: Failed to change directory to $PROJECT_PATH"; exit 1; }

if [ -f "$CURRENT_PATH/temp-env/bin/activate" ]; then
    source "$CURRENT_PATH/temp-env/bin/activate"
    echo "Activated virtual environment from temp-env"
else
    echo "Error: temp-env/bin/activate not found in $CURRENT_PATH"
    return 1
fi



echo "================================================================"
echo "================================================================"
echo "Starting the build and deployment process..."
make clean && make && ./deploy.sh

echo "================================================================"
echo "================================================================"
echo "Starting service"
sudo systemctl restart openvpn-client

curl -s --socks5-hostname 127.0.0.1:1080 https://ifconfig.me

