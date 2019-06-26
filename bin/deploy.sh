#!/usr/bin/env bash

# extract secrets from vault, copy to remote host, and launch boot script for deployment

THIS_DIR="$(cd "$(dirname "$0")"; pwd)"

# common libraries
. $THIS_DIR/bash_utils.sh
. $THIS_DIR/extract_vault_secrets.sh
. $THIS_DIR/docker_utils.sh


# defaults
SSH_USER="jenkins"
SSH_OPTS="-o CheckHostIP=no -o StrictHostKeyChecking=no"
SSH_COMMAND="ssh $SSH_OPTS $SSH_USER@$DESTINATION_HOST"
DESTINATION_BASE_DIR='/home/docker-user/deployments/single_cell_portal_core'
GIT_BRANCH="master"
PASSENGER_APP_ENV="production"
BOOT_COMMAND="bin/boot_deployment.sh"

usage=$(
cat <<EOF

### boot deployment on remote server once all secrets/source code has been staged and Docker container is stopped ###
$0

[OPTIONS]
-p VALUE	set the path to configuration secrets in vault
-s VALUE	set the path to the main service account json in vault
-r VALUE	set the path to the read-only service account json in vault
-e VALUE	set the environment to boot the portal in
-b VALUE	set the branch to pull from git (defaults to master)
-d VAULE	set the target directory to deploy from (defaults to $DESTINATION_BASE_DIR)
-H COMMAND	print this text
EOF
)

while getopts "p:s:r:c:n:e:b:d:H" OPTION; do
case $OPTION in
  p)
    PORTAL_SECRETS_VAULT_PATH="$OPTARG"
    ;;
  s)
    SERVICE_ACCOUNT_VAULT_PATH="$OPTARG"
    ;;
  r)
    READ_ONLY_SERVICE_ACCOUNT_VAULT_PATH="$OPTARG"
    ;;
  e)
    PASSENGER_APP_ENV="$OPTARG"
    ;;
  b)
    GIT_BRANCH="$OPTARG"
    ;;
  d)
    DESTINATION_BASE_DIR="$OPTARG"
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

function main {
    # exit if all config is not present
    if [[ -z "$PORTAL_SECRETS_VAULT_PATH" ]] || [[ -z "$SERVICE_ACCOUNT_VAULT_PATH" ]] || [[ -z "$READ_ONLY_SERVICE_ACCOUNT_VAULT_PATH" ]]; then
        exit_with_error_message "Did not supply all necessary parameters: portal config: $PORTAL_SECRETS_VAULT_PATH" \
            "service account path: $SERVICE_ACCOUNT_VAULT_PATH; read-only service account path: $READ_ONLY_SERVICE_ACCOUNT_VAULT_PATH"
    fi

    echo "### extracting secrets from vault ###"
    CONFIG_FILENAME="$(set_export_filename $PORTAL_SECRETS_VAULT_PATH env)"
    SERVICE_ACCOUNT_FILENAME="$(set_export_filename $SERVICE_ACCOUNT_VAULT_PATH)"
    READ_ONLY_SERVICE_ACCOUNT_FILENAME="$(set_export_filename $READ_ONLY_SERVICE_ACCOUNT_VAULT_PATH)"
    extract_vault_secrets_as_env_file "$PORTAL_SECRETS_VAULT_PATH"
    extract_service_account_credentials "$SERVICE_ACCOUNT_VAULT_PATH"
    extract_service_account_credentials "$READ_ONLY_SERVICE_ACCOUNT_VAULT_PATH"
    PORTAL_SECRETS_PATH="$DESTINATION_BASE_DIR/config/$CONFIG_FILENAME"
    SERVICE_ACCOUNT_JSON_PATH="$DESTINATION_BASE_DIR/config/$SERVICE_ACCOUNT_FILENAME"
    READ_ONLY_SERVICE_ACCOUNT_JSON_PATH="$DESTINATION_BASE_DIR/config/$READ_ONLY_SERVICE_ACCOUNT_FILENAME"
    echo "### COMPLETED ###"

    echo "### migrating secrets to remote host ###"
    mv ./$CONFIG_FILENAME $PORTAL_SECRETS_PATH || exit_with_error_message "could not move $CONFIG_FILENAME to $PORTAL_SECRETS_PATH"
    mv ./$SERVICE_ACCOUNT_FILENAME $SERVICE_ACCOUNT_JSON_PATH || exit_with_error_message "could not move $SERVICE_ACCOUNT_FILENAME to $SERVICE_ACCOUNT_JSON_PATH"
    mv ./$READ_ONLY_SERVICE_ACCOUNT_FILENAME $READ_ONLY_SERVICE_ACCOUNT_JSON_PATH || exit_with_error_message "could not move $READ_ONLY_SERVICE_ACCOUNT_FILENAME to $READ_ONLY_SERVICE_ACCOUNT_JSON_PATH"

    echo "### pulling updated source from git on branch $GIT_BRANCH ###"
    cd $DESTINATION_BASE_DIR ; git fetch && git checkout $GIT_BRANCH || exit_with_error_message "could not pull from $GIT_BRANCH"
    echo "### COMPLETED ###"

    echo "### booting deployment ###"
    BOOT_COMMAND=$BOOT_COMMAND" -e $PASSENGER_APP_ENV -p $PORTAL_SECRETS_PATH -s $SERVICE_ACCOUNT_JSON_PATH -r $READ_ONLY_SERVICE_ACCOUNT_JSON_PATH"
    cd $DESTINATION_BASE_DIR ; $BOOT_COMMAND || exit_with_error_message "could not boot new instance"
}

main "$@"