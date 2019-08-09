#!/usr/bin/env bash

THIS_DIR="$(cd "$(dirname "$0")"; pwd)"

# common libraries
. $THIS_DIR/bash_utils.sh
. $THIS_DIR/docker_utils.sh

# runs deployment on a remote host (different from deploy.sh which runs on a Jenkins node)

function main {
    # make sure that all necessary variables have been set
    PORTAL_CONTAINER="single_cell"
    PORTAL_CONTAINER_VERSION="latest"
    echo "### USER: $(whoami) ###"

    if [[ -z "$PORTAL_SECRETS_PATH" ]] || [[ -z "$DESTINATION_BASE_DIR" ]]; then
        exit_with_error_message "Not all necessary variables have been set: Git branch: $GIT_BRANCH; " \
            "secrets: $PORTAL_SECRETS_PATH; base directory: $DESTINATION_BASE_DIR"
    fi

    # build a new docker container now to save time later
    echo "### Building new docker image: $PORTAL_CONTAINER:$PORTAL_CONTAINER_VERSION ... ###"
    build_docker_image $DESTINATION_BASE_DIR $PORTAL_CONTAINER $PORTAL_CONTAINER_VERSION || exit_with_error_message "Cannot build new docker image"
    echo "### COMPLETED ###"

    # stop docker container and remove it
    if [[ $(ensure_container_running $PORTAL_CONTAINER) = "0" ]]; then
        echo "### Stopping running container $PORTAL_CONTAINER ###"
        stop_docker_container $PORTAL_CONTAINER || exit_with_error_message "Cannot stop docker container $PORTAL_CONTAINER"
    fi
    for container in $(get_all_containers); do
       if [[ "$container" = "$PORTAL_CONTAINER" ]]; then
           echo "### Removing docker container $PORTAL_CONTAINER ... ###"
           remove_docker_container $PORTAL_CONTAINER || exit_with_error_message "Cannot remove docker container $PORTAL_CONTAINER"
       fi
    done
    echo "### COMPLETED ###"

    # load env secrets from file, then clean up
    echo "### loading env secrets ###"
    . $PORTAL_SECRETS_PATH
    echo "### COMPLETED ###"

    # run boot command
    echo "### Booting $PORTAL_CONTAINER ###"
    run_command_in_deployment "bin/boot_docker -e $PASSENGER_APP_ENV -d $DESTINATION_BASE_DIR -h $PROD_HOSTNAME -N $PORTAL_NAMESPACE -m $MONGO_LOCALHOST"
    echo "### COMPLETED ###"

    # ensure portal is running
    echo "### Ensuring boot ###"
    COUNTER=0
    while [[ $COUNTER -lt 12 ]]; do
		    COUNTER=$[$COUNTER + 1]
		    echo "portal not running on attempt $COUNTER, waiting 5 seconds..."
		    sleep 5
		    if [[ $(ensure_container_running $PORTAL_CONTAINER) = "0" ]]; then break 2; fi
    done
    if [[ $(ensure_container_running $PORTAL_CONTAINER) = "1" ]] ; then exit_with_error_message "Portal still not running after 1 minute, deployment failed" ; fi
    echo "### COMPLETED ###"

    echo "### Cleaning up ###"
    rm $PORTAL_SECRETS_PATH
    echo "### DEPLOYMENT COMPLETED ###"
}

function run_command_in_deployment {
    COMMAND="$1"
    cd $DESTINATION_BASE_DIR ; $COMMAND
}

main "$@"