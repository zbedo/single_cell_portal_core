#!/usr/bin/env bash

# extract secrets from vault, copy to remote host, and launch boot script for deployment

THIS_DIR="$(cd "$(dirname "$0")"; pwd)"

# common libraries
. $THIS_DIR/bash_utils.sh
. $THIS_DIR/extract_vault_secrets.sh

# defaults
SSH_USER="jenkins"
SSH_OPTS="-o CheckHostIP=no -o StrictHostKeyChecking=no"
SSH_COMMAND="ssh $SSH_OPTS $SSH_USER@$DESTINATION_HOST"
DESTINATION_BASE_DIR='/home/docker-user/deployments/single_cell_portal_core'
BOOT_COMMAND="$DESTINATION_BASE_DIR/bin/boot_deployment.sh"

while getopts "p:s:r:c:n:e:H" OPTION; do
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
    PORTAL_SECRETS_PATH="/tmp/$CONFIG_FILENAME"
    SERVICE_ACCOUNT_JSON_PATH="/tmp/$SERVICE_ACCOUNT_FILENAME"
    READ_ONLY_SERVICE_ACCOUNT_JSON_PATH="/tmp/$READ_ONLY_SERVICE_ACCOUNT_FILENAME"
    mv ./$CONFIG_FILENAME $PORTAL_SECRETS_PATH || exit_with_error_message "could not move $CONFIG_FILENAME to $PORTAL_SECRETS_PATH"
    mv ./$SERVICE_ACCOUNT_FILENAME $SERVICE_ACCOUNT_JSON_PATH || exit_with_error_message "could not move $SERVICE_ACCOUNT_FILENAME to $SERVICE_ACCOUNT_JSON_PATH"
    mv ./$READ_ONLY_SERVICE_ACCOUNT_FILENAME $READ_ONLY_SERVICE_ACCOUNT_JSON_PATH || exit_with_error_message "could not move $READ_ONLY_SERVICE_ACCOUNT_FILENAME to $READ_ONLY_SERVICE_ACCOUNT_JSON_PATH"
    echo "### COMPLETED ###"

    echo "### migrating secrets to remote host ###"

    echo "### booting deployment ###"
}

main "$@"