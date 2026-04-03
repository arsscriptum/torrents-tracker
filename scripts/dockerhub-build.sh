#!/bin/bash

# ┌────────────────────────────────────────────────────────────────────────────────┐
# │                                                                                │
# │   dockerhub-build.sh                                                           │
# │                                                                                │
# ┼────────────────────────────────────────────────────────────────────────────────┼
# │   Guillaume Plante  <guillaumeplante.qc@gmail.com>                             │
# └────────────────────────────────────────────────────────────────────────────────┘


SCRIPT_PATH=$(realpath "$BASH_SOURCE")
SCRIPT_DIR=$(dirname "$SCRIPT_PATH")

tmp_root=$(pushd "$SCRIPT_DIR/.." | awk '{print $1}')
ROOT_DIR=$(eval echo -e "$tmp_root")
ROOT_DIRECTORY="$ROOT_DIR"
SCRIPTS_DIRECTORY="$ROOT_DIR/scripts"

OWNER="arsscriptum"
IMAGE_NAME="torrents-tracker"
RepositoryName="$OWNER/$IMAGE_NAME"
TagName="1.5"
TagLatest=latest

pushd $ROOT_DIRECTORY > /dev/null

LogCategory=DockerHub
 
# Source the logging functions

if [ ! -d "$LOGGING" ]; then
    source /srv/scripts/logging.sh
else
    source $LOGGING
fi

log_il "\ndockerhub-build.sh - a build script for docker compose images\n"



# Stop the container if it's running
if docker ps | grep -q "$IMAGE_NAME"; then
    echo "Stopping $IMAGE_NAME container..."
    docker stop "$IMAGE_NAME"
fi

# Remove the container if it exists
if docker ps -a | grep -q "$IMAGE_NAME"; then
    echo "Removing $IMAGE_NAME container..."
    docker rm "$IMAGE_NAME"
fi


# Start the new container
# ...
log_warning "Step 1 - BUILDING"

docker build --no-cache -t "$OWNER/$IMAGE_NAME:$TagName" .
if [ $? -eq 0 ]; then
    log_ok "building success"
else
    log_error "An error occurred while building the docker image"
    exit 1
fi





log_warning "Remove Dangling Image - remove unused and dangling images after rebuilding to save space"

# Remove Dangling Images: You can remove unused and dangling images after rebuilding to save space
docker image prune -f


log_warning "Step 2 - TAGGING $RepositoryName:$TagName"

docker tag $RepositoryName:$TagName $RepositoryName:$TagName

if [ $? -eq 0 ]; then
    log_ok "tagging success"
else
    log_error "An error occurred while tagging the project."
    exit 1
fi


log_warning "Step 3 PUSHING $TagName"


docker push $RepositoryName:$TagName

if [ $? -eq 0 ]; then
    log_ok "Pushed successfully"
else
    log_error "An error occurred while pushing the image."
    exit 1
fi


log_warning "Step 2 - TAGGING LATEST $RepositoryName:$TagLatest"

docker tag $RepositoryName:$TagName $RepositoryName:$TagLatest

if [ $? -eq 0 ]; then
    log_ok "tagging success"
else
    log_error "An error occurred while tagging the project."
    exit 1
fi


log_warning "Step 3 PUSHING $TagLatest"


docker push $RepositoryName:$TagLatest

if [ $? -eq 0 ]; then
    log_ok "Pushed successfully"
else
    log_error "An error occurred while pushing the image."
    exit 1
fi


popd > /dev/null


log_ok "ok!"
