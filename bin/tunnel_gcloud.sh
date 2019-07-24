#!/usr/bin/env bash

# tunnel into GCP VM for deployments/updates

# usage error message
usage=$(
cat <<EOF
$0 [OPTION]
-v VALUE	set the VM name, defaults to 'singlecell-production'.
-u VALUE	set the login user, defaults to 'root'
-p VALUE	set the GCP project, defaults to 'broad-singlecellportal'
-H COMMAND	print this text
EOF
)

# set variables & defaults
VM_NAME="singlecell-production-101"
PROJECT="broad-singlecellportal"
USER='ubuntu'

while getopts "v:u:p:H" OPTION; do
case $OPTION in
    v)
        VM_NAME="$OPTARG"
        ;;
    u)
        USER="$OPTARG"
        ;;
    p)
        PROJECT="$OPTARG"
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

gcloud compute ssh $USER@$VM_NAME --project $PROJECT --zone us-central1-a