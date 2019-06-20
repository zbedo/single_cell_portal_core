#!/usr/bin/env bash

# shell shortcuts for starting/stopping/removing docker containers

# load common utils

. ./bash_utils.sh

# defaults

PORTAL_DOCKER_CONTAINER="single_cell"
PORTAIL_DOCKER_CONTAINER_VERSION="latest"

# set the docker container name
function set_container_name {
    CONTAINER="$1"
    if [[ -z $CONTAINER ]]; then
        CONTAINER=$PORTAL_DOCKER_CONTAINER
    fi
    echo "$CONTAINER"
}

# get all running containers
function get_running_containers {
    echo $(docker ps -a --format '{{.Names}}' -f=status=running) || exit_with_error_message "could not list running containers"
}

# stop a docker container
function stop_docker_container {
    CONTAINER_NAME=$(set_container_name $1)
    docker stop $CONTAINER_NAME || exit_with_error_message "docker could not stop container: $CONTAINER_NAME"
}

# remove a container
function remove_docker_container {
    CONTAINER_NAME=$(set_container_name $1)
    docker rm $CONTAINER_NAME || exit_with_error_message "docker could not stop container: $CONTAINER_NAME"
}

# ensure that container is running
function ensure_container_running {
    CONTAINER_NAME=$(set_container_name $1)
    RUNNING_CONTAINERS=$(get_running_containers)
    RUNNING=false
    for CONTAINER in $RUNNING_CONTAINERS; do
        if [[ "$CONTAINER" = "$CONTAINER_NAME" ]]; then
            RUNNING=true
        fi
    done

}