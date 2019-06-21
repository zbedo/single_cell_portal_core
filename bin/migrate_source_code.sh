#!/usr/bin/env bash

# copy new source code for a deployment while persisting specific artifacts that are not part of source,
# such as log files, user-generated content, and pre-compiled libraries, and archiving previous releases for backups

# load common utils
. ./bash_utils.sh

# create a tmp dir name with base directory name & date
function create_backup_dirname {
    PREV_RELEASE="$1"
    BASE_DIR=$(extract_terminal_pathname $PREV_RELEASE)
    CURRENT_DATE="$(date +%Y-%m-%d)"
    NEW_PATH="/tmp/$BASE_DIR-$CURRENT_DATE-backup"
    echo "$NEW_PATH"
}

# move a directory from one location to another; can be used to archive a previous release or stage a new one
function move_directory {
    SOURCE_LOCATION="$1"
    TARGET_DIR="$2"
    if [[ -z $SOURCE_LOCATION ]] || [[ -z $TARGET_DIR ]]; then
        exit_with_error_message "did not supply source/target location when moving release; SOURCE: $SOURCE_LOCATION, TARGET: $TARGET_DIR"
    fi
    if [[ -d $NEW_PATH ]]; then
        exit_with_error_message "cannot move $SOURCE_LOCATION to $TARGET_DIR; directory exists"
    else
        echo "moving $SOURCE_LOCATION to $TARGET_DIR"
        mv $SOURCE_LOCATION $TARGET_DIR || exit_with_error_message "unable to move $SOURCE_LOCATION to $TARGET_DIR"
    fi
}

# copy artifacts from a previous release into the current one
# for things like log files, user-generated content, and pre-compiled libraries
function copy_artifacts_from_previous_release {
    ARTIFACT_PATH="$1"
    TARGET_DIR="$2"
    if [[ -z $ARTIFACT_PATH ]] || [[ -z $TARGET_DIR ]]; then
        exit_with_error_message "did not supply source/target location when copying artifacts; ARTIFACTS: $ARTIFACT_PATH, TARGET: $TARGET_DIR"
    fi
    echo "copying $ARTIFACT_PATH to $TARGET_DIR"
    cp -Rp $ARTIFACT_PATH $TARGET_DIR
}