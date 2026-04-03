#!/bin/bash

# Check if the script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Error: This script must be run as root." >&2
  exit 1
fi

LOG_DIR=/srv/logs/torrents-tracker

# Get the directory of the script and the root directory
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(cd "$SCRIPT_DIR/.." && pwd)

echo "SCRIPT_DIR = $SCRIPT_DIR"

echo "ROOT_DIR = $ROOT_DIR"


SRC_DIR=$ROOT_DIR
DEST_DIR="/home/services/www/torrents-tracker/"

# Arrays for directories and files to copy
DIRECTORIES=( "www" "db" "tracker" "yaml" "project")
FILES=("build.nfo" "version.nfo" "manage.py" "Dockerfile" "requirements.txt", ".env")


# Define the service name
SERVICE_NAME="torrents-tracker.service"

# Function to check if the service is active
is_service_active() {
    systemctl is-active --quiet "$SERVICE_NAME"
}

# Check if the service is running
if is_service_active; then
    echo "Service '$SERVICE_NAME' is running. Stopping it now..."
    # Stop the service
    systemctl stop "$SERVICE_NAME"

    # Wait until the service has stopped
    while is_service_active; do
        echo "Waiting for the service '$SERVICE_NAME' to stop..."
        sleep 1
    done

    echo "Service '$SERVICE_NAME' has stopped."
else
    echo "Service '$SERVICE_NAME' is not running."
fi

mkdir -p $DEST_DIR

echo "Setting permissions..."
chown -R www-data:www-data "$DEST_DIR"
chmod -R 777 "$DEST_DIR"

mkdir -p $LOG_DIR

echo "Setting permissions..."
chown -R www-data:www-data "$LOG_DIR"
chmod -R 777 "$LOG_DIR"

# Copy necessary directories to the destination
echo "Copying directories to production directory..."
rsync -av --exclude='.git' --exclude='scripts' $SRC_DIR $DEST_DIR

# Copy the production docker-compose file
COMPFILE_PATH="$DEST_DIR/docker-compose.yml"
COMPFILE_PRODUCTION="$ROOT_DIR/yaml/docker-compose_full.yml"
cp --verbose --force "$COMPFILE_PRODUCTION" "$COMPFILE_PATH"


DEST_BUILD_NFO="$DEST_DIR/build.nfo"
# Update only the first line
sed -i '1s/.*/official-prod/' "$DEST_BUILD_NFO"

# Provide feedback to the user
echo "The first line of '$DEST_BUILD_NFO' has been updated to 'official-prod'."


# Provide feedback to user
echo "Deployment to $DEST_DIR completed successfully."

# Set appropriate permissions


echo "Permissions have been set."

# Change to the destination directory
pushd "$DEST_DIR"

# Start the service again
echo "Starting the service '$SERVICE_NAME'..."
systemctl start "$SERVICE_NAME"

# Provide feedback to the user
if is_service_active; then
    echo "Service '$SERVICE_NAME' has started successfully."
else
    echo "Failed to start the service '$SERVICE_NAME'."
fi

popd