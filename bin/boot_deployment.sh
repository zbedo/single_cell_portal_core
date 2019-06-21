#!/usr/bin/env bash

# boot deployment on remote server once all secrets/source code has been staged and Docker container is stopped

# common libraries
. ./bash_utils.sh
. ./docker_utils.sh
. ./migrate_source_code.sh

usage=$(
cat <<EOF

### boot deployment on remote server once all secrets/source code has been staged and Docker container is stopped ###
$0

[OPTIONS]
-p VALUE	set the filepath to the secrets env file (will be cleaned up on boot)
-s VALUE	set the filepath to the service account credentials on disk
-r VALUE	set the filepath to the 'read-only' service account credentials on disk
-c VALUE	set the fully qualified path to the current release
-n VALUE	set the path to the new or 'staged' release that is being deployed
-e VALUE	set the environment to boot the portal in (defaults to development)
-H COMMAND	print this text
EOF
)

# defaults
PASSENGER_APP_ENV="production"
COMMAND="bin/boot_docker"
PORTAL_CONTAINER="single_cell"
PORTAL_CONTAINER_VERSION="latest"
ARTIFACTS_TO_MIGRATE=(logs/* public/single_cell tcell tmp)

# parse options
while getopts "p:s:r:c:n:e:H" OPTION; do
case $OPTION in
  p)
    PORTAL_SECRETS="$OPTARG"
    ;;
  s)
    SERVICE_ACCOUNT_PATH="$OPTARG"
    ;;
  r)
    READ_ONLY_SERVICE_ACCOUNT_PATH="$OPTARG"
    ;;
  c)
    CURRENT_RELEASE="$OPTARG"
    ;;
  n)
    NEW_RELEASE="$OPTARG"
    ;;
  e)
    PASSENGER_APP_ENV="$OPTARG"
    ;;
  H)
    echo "$usage"
    exit 0
    ;;
  *)
    echo "unrecognized option"
    echo "$usage"
    ;;
  esac
done

# pre-populate an error message for first check when calling main
ERROR_MSG=$(
cat <<EOF

Cannot boot portal, necessary secrets and paths have not been loaded (must have values for all of these):
config: $PORTAL_SECRETS
service account: $SERVICE_ACCOUNT_PATH
r/o service account: $READ_ONLY_SERVICE_ACCOUNT_PATH
current release: $CURRENT_RELEASE
new release: $NEW_RELEASE
EOF
)

function main {
    # exit if all config is not present
    if [[ -z "$PORTAL_SECRETS" ]] || [[ -z "$SERVICE_ACCOUNT_PATH" ]] || [[ -z "$READ_ONLY_SERVICE_ACCOUNT_PATH" ]] || \
       [[ -z "$CURRENT_RELEASE" ]] || [[ -z "$NEW_RELEASE" ]]; then

        exit_with_error_message $ERROR_MSG
    fi

    # set service account keys
    echo "### Exporting Service Account Keys: $SERVICE_ACCOUNT_PATH, $READ_ONLY_SERVICE_ACCOUNT_PATH ###"
    echo "export SERVICE_ACCOUNT_KEY=$SERVICE_ACCOUNT_PATH" >> $PORTAL_SECRETS
    echo "export READ_ONLY_SERVICE_ACCOUNT_KEY=$READ_ONLY_SERVICE_ACCOUNT_PATH" >> $PORTAL_SECRETS
    echo "### COMPLETED ###"

    # load env secrets from file, then clean up
    echo "### Exporting portal configuration from $PORTAL_SECRETS and cleaning up... ###"
    . $PORTAL_SECRETS
    rm $PORTAL_SECRETS
    echo "### COMPLETED ###"

    # build a new docker container now to save time later
    echo "### Building new docker image: $PORTAL_CONTAINER:$PORTAL_CONTAINER_VERSION ... ###"
    build_docker_image $NEW_RELEASE $PORTAL_CONTAINER $PORTAL_CONTAINER_VERSION
    echo "### COMPLETED ###"

    # stop docker container and remove it
    echo "### Stopping & removing docker container $PORTAL_CONTAINER ... ###"
    stop_docker_container $PORTAL_CONTAINER
    remove_docker_container $PORTAL_CONTAINER
    echo "### COMPLETED ###"

    # migrate source & copy artifacts
    echo "### Creating backup of $CURRENT_RELEASE ... ###"
    BACKUP_DIR="$(create_backup_dirname $CURRENT_RELEASE)" || exit_with_error_message "could not generate a backup dirname for $CURRENT_RELEASE"
    move_directory $CURRENT_RELEASE $BACKUP_DIR
    echo "### COMPLETED ###"
    echo "### Staging new release to $CURRENT_RELEASE ... ###"
    move_directory $NEW_RELEASE $CURRENT_RELEASE
    echo "### COMPLETED ###"
    echo "### Migrating ${ARTIFACTS_TO_MIGRATE[*]} to $NEW_RELEASE ... ###"
    for ARTIFACT in ${ARTIFACTS_TO_MIGRATE[*]}; do
        OLD_PATH="$BACKUP_DIR/$ARTIFACT"
        NEW_PATH="$CURRENT_RELEASE/$ARTIFACT"
        copy_artifacts_from_previous_release $OLD_PATH $NEW_PATH
    done
    echo "### COMPLETED ###"

    # run boot command
    echo "### Booting $PORTAL_CONTAINER ###"
    $COMMAND -e $PASSENGER_APP_ENV
    echo "### COMPLETED ###"

    # ensure portal is running
    echo "### Ensuring boot ###"
    COUNTER=0
    while [[ $COUNTER -lt 12 ]]; do
        COUNTER=$[$COUNTER + 1]
        echo "portal not running on attempt $COUNTER, waiting 5 seconds..."
        sleep 5
        if [[ $(ensure_container_running $PORTAL_CONTAINER) -eq 0 ]]; then break 2; fi
    done
    ensure_container_running $PORTAL_CONTAINER || exit_with_error_message "Portal still not running after 1 minute, deployment failed"
    echo "### DEPLOYMENT COMPLETED ###"
}

main "$@"