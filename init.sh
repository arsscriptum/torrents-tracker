#!/bin/bash

# Step 1: Get the current path
CURRENT_PATH=$(pwd)
echo "Current path: $CURRENT_PATH"

# Step 2: Rename docker-compose.origin to docker-compose.yml
if [ -f "$CURRENT_PATH/docker-compose.origin" ]; then
    mv "$CURRENT_PATH/docker-compose.origin" "$CURRENT_PATH/docker-compose.yml"
    echo "Renamed docker-compose.origin to docker-compose.yml"
    echo "start the app using 'docker-compose up --build'"
else
    echo "Error: docker-compose.origin not found in $CURRENT_PATH"
    exit 1
fi

# Step 3: Run the git commands
git update-index --assume-unchanged docker-compose.origin
git update-index --assume-unchanged build.nfo
git update-index --assume-unchanged version.nfo

echo "Git commands executed successfully."

