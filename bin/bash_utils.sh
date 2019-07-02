#!/usr/bin/env bash

# common functions to share amongst different bash scripts for running/deploying SCP docker container

# https://stackoverflow.com/a/56841815/1735179
newline='
'

# exit 1 with an error message
function exit_with_error_message {
    echo "ERROR: $@" >&2;
    exit 1
}

function extract_pathname_extension {
    FULL_PATH="$1"
    SEP="."
    echo ${FULL_PATH##*.} || exit_with_error_message "could not extract file extension from $FULL_PATH"
}
