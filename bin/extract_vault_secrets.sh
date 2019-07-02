#!/usr/bin/env bash

# load secrets from Vault for running/deploying SCP docker container

# defaults
THIS_DIR="$(cd "$(dirname "$0")"; pwd)"
DOCKER_IMAGE_FOR_VAULT_CLIENT='vault:1.1.3'
export VAULT_ADDR
export JENKINS_VAULT_TOKEN_PATH

# load common utils
. $THIS_DIR/bash_utils.sh

# TODO: consider renaming--"set" is misleading since no value is being stored anywhere. "echo", "show", "calculate", "determine" are some other ideas for verbs
# extract filename from end of vault path, replacing with new extension if needed
function set_export_filename {
    SECRET_PATH="$1"
    REQUESTED_EXTENSION="$2"
    FILENAME=$(basename $SECRET_PATH)
    if [[ -n "$REQUESTED_EXTENSION" ]]; then
        # replace existing extension with requested extension (like .env for non-JSON secrets)
        EXPORT_EXTENSION="$(extract_pathname_extension $FILENAME)"
        FILENAME="$(echo $FILENAME | sed "s/$EXPORT_EXTENSION/$REQUESTED_EXTENSION/")" || exit_with_error_message "could not change export filename extension to $REQUESTED_EXTENSION from $EXPORT_EXTENSION"
    fi
    echo "$FILENAME"
}

# extract Google Service Account credentials and write to a JSON file
# this file is not compatible with GCS libraries, will need to be parsed with jq utility
function extract_service_account_credentials {
    CREDENTIALS_PATH="$1"
    echo "setting filename for $CREDENTIALS_PATH export"
    CREDENTIALS_FILENAME=$(set_export_filename $CREDENTIALS_PATH)
    echo "extracting service account credentials from $CREDENTIALS_PATH"
    CREDS=$(load_secrets_from_vault $CREDENTIALS_PATH) || exit_with_error_message "error reading credentials from vault"
    JSON_CONTENTS=$(echo $CREDS | jq --raw-output .data) || exit_with_error_message "error parsing $CREDENTIALS_PATH contents"
    echo $JSON_CONTENTS >| $CREDENTIALS_FILENAME || exit_with_error_message "could not write $CREDENTIALS_PATH to $CREDENTIALS_FILENAME"
}

# extract generic JSON vault secrets and
function extract_vault_secrets_as_env_file {
    VAULT_SECRET_PATH="$1"
    echo "setting filename for $VAULT_SECRET_PATH export"
    SECRET_EXPORT_FILENAME="$(set_export_filename $VAULT_SECRET_PATH env)"
    # load raw secrets from vault
    echo "extracting vault secrets from $VAULT_SECRET_PATH"
    VALS=$(load_secrets_from_vault $VAULT_SECRET_PATH) || exit_with_error_message "could not read secrets from $VAULT_SECRET_PATH"
    echo "### env secrets from $VAULT_SECRET_PATH ###" >| $SECRET_EXPORT_FILENAME || exit_with_error_message "could not initialize $SECRET_EXPORT_FILENAME"
    # for each key in the secrets config, export the value
    for key in $(echo $VALS | jq .data | jq --raw-output 'keys[]')
    do
        echo "setting value for: $key"
        curr_val=$(echo $VALS | jq .data | jq --raw-output .$key) || exit_with_error_message "could not extract value for $key from $VAULT_SECRET_PATH"
        echo "export $key=$curr_val" >> $SECRET_EXPORT_FILENAME
    done
}

# get the token for authenticating into vault; will default to local machine's github-token
function get_vault_token {
    if [[ -f $JENKINS_VAULT_TOKEN_PATH ]]; then
        echo $(cat $JENKINS_VAULT_TOKEN_PATH)
    else
        echo $(cat ~/.github-token)
    fi
}

# load secrets out of vault using Docker image defined in $DOCKER_IMAGE_FOR_VAULT_CLIENT
# TODO: let's chat about vault tokens---it looks like you might have copy-pasted some stuff you don't need here, or maybe you know something I don't. Also I recently figured out some problems in my understanding of these tokens that manifested itself in mmrf-researcher-portal scripts:
function load_secrets_from_vault {
    SECRET_PATH_IN_VAULT="$1"

    docker run --rm \
        -e VAULT_AUTH_GITHUB_TOKEN \
        -e VAULT_AUTH_NATIVE_TOKEN \
        -e VAULT_ADDR \
        $DOCKER_IMAGE_FOR_VAULT_CLIENT \
        sh -lc "vault login -method=github -no-print=true token=$(get_vault_token) && vault read -format json $SECRET_PATH_IN_VAULT" || exit_with_error_message "could not read $SECRET_PATH_IN_VAULT"
}
