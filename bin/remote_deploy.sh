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

    PORTAL_HOMEPAGE="https://$PROD_HOSTNAME/single_cell"
    echo "### ENSURING PORTAL IS AVAILABLE AT $PORTAL_HOMEPAGE ###"
    HOMEPAGE_COUNTER=0
    while [[ $HOMEPAGE_COUNTER -lt 24 ]]; do
		    HOMEPAGE_COUNTER=$[$HOMEPAGE_COUNTER + 1]
		    echo "home page not available on attempt $HOMEPAGE_COUNTER, waiting 15 seconds..."
		    sleep 15
		    if [[ $(get_http_status_code $PORTAL_HOMEPAGE) = "200" ]]; then echo "DEBUG: hooray, got a 200 back from $PORTAL_HOMEPAGE";break 2; fi
    done
    if [[ $(get_http_status_code $PORTAL_HOMEPAGE) != "200" ]] ; then exit_with_error_message "Portal still not available at $PORTAL_HOMEPAGE after 3 minutes, deployment failed" ; fi
    echo "### Cleaning up ###"
    rm $PORTAL_SECRETS_PATH
    echo "### DEPLOYMENT COMPLETED ###"
}

function run_command_in_deployment {
    COMMAND="$1"
    cd $DESTINATION_BASE_DIR ; $COMMAND
}

# make a HEAD request on URL and return HTTP status code
function get_http_status_code {
    URL="$1"
    echo $(curl -Isk $URL | head -n 1 | awk '{ print $2 }')
}


main "$@"
