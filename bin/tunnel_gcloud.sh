#!/usr/bin/env bash

# tunnel into GCP VM for deployments/updates

# usage error message
usage=$(
cat <<EOF
$0 [OPTION]
-e VALUE	set the environment, defaults to 'production' (determines which VM to ssh into).
-u VALUE	set the login user, defaults to 'root'
-H COMMAND	print this text
EOF
)

# set variables & defaults
ENV="production"
USER='root'

while getopts "e:u:H" OPTION; do
case $OPTION in
	e)
		ENV="$OPTARG"
		;;
	u)
		USER="$OPTARG"
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

gcloud compute ssh $USER@singlecell-$ENV --project broad-singlecellportal --zone us-central1-a