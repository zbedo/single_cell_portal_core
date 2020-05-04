#!/usr/bin/env bash

# functions for retrieving Github releases for SCP and extracting requested release attributes
# by walking back through release history
#
# Requirements: curl, jq

REPO_URL='https://api.github.com/repos/broadinstitute/single_cell_portal_core/releases'

# Get all Github published releases for $REPO_URL
function get_all_releases {
  echo $(curl -X GET --header 'application/json' --silent $REPO_URL)
}

# extract an attribute from a Github release object JSON
# will default to using "tag_name", and targeting the previous release from the most recent
function extract_release_attribute {
  OFFSET="$1"
  RELEASE_ATTR="$2"
  if [[ -z "$OFFSET" ]]; then
    OFFSET="1"
  fi
  if [[ -z "$RELEASE_ATTR" ]]; then
    RELEASE_ATTR="tag_name"
  fi
  echo $(get_all_releases | jq ".[$OFFSET].$RELEASE_ATTR" | sed 's/"//g')
}
