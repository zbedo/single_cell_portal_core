#!/usr/bin/env bash

# common functions to share amongst different bash scripts for running/deploying SCP docker container

# exit 1 with an error message
function exit_with_error_message {
    echo $1 1>&2;
    exit 1
}

# extract last element of a path (everything after last /)
# from https://stackoverflow.com/questions/3162385
# uses string operators, where:
# ## greedy front trim
# * match anything
# / until last "/"
#
# pathname with no slashes returns $FULL_PATH
function extract_terminal_pathname {
    FULL_PATH="$1"
    SEP="/"
    # make sure path does not terminate in a slash
    if [[ "$(echo -n $FULL_PATH | tail -c 1)" = "$SEP" ]]; then
        FULL_PATH="${FULL_PATH%?}"
    fi
    echo ${FULL_PATH##*/} || exit_with_error_message "could not extract final path from $FULL_PATH"
}

function extract_pathname_extension {
    FULL_PATH="$1"
    SEP="."
    echo ${FULL_PATH##*.} || exit_with_error_message "could not extract file extension from $FULL_PATH"
}