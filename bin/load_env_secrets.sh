#! /bin/bash

# load_env_secrets.sh
#
# shell script to export environment variables from Vault secrets or a JSON configuration file and then boot portal
# requires the jq utility: https://stedolan.github.io/jq/ and vault: https://www.vaultproject.io

# usage error message
usage=$(
cat <<EOF
[OPTIONS]
-p VALUE	set the path to the Vault configuration object
-c VALUE	set the path to the service account credentials object in Vault
-f VALUE	set the path to the local JSON configuration file
-e VALUE	set the environment to boot the portal in (defaults to development)
-H COMMAND	print this text
EOF
)

# defaults
PASSENGER_APP_ENV="development"
while getopts "p:c:f:e:bH" OPTION; do
case $OPTION in
	p)
		VAULT_SECRET_PATH="$OPTARG"
		;;
	c)
		SERVICE_ACCOUNT_PATH="$OPTARG"
		;;
	f)
		CONFIG_FILE_PATH="$OPTARG"
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
# if user supplies a path to a configuration file, use that first
if [ -z $VAULT_SECRET_PATH ] && [ -n $CONFIG_FILE_PATH ] ; then
	# load raw secrets from config JSON file
	VALS=`echo -n $(cat $CONFIG_FILE_PATH)`
	# for each key in the secrets config, export the value
	for key in `echo $VALS | jq --raw-output 'keys[]'`
	do
		echo "setting value for: $key"
		curr_val=$(echo $VALS | jq --raw-output .$key)
		export $key=$curr_val
	done

elif [ -n $VAULT_SECRET_PATH ] ; then
	# load raw secrets from vault
	VALS=`vault read -format=json $VAULT_SECRET_PATH`

	# for each key in the secrets config, export the value
	for key in `echo $VALS | jq .data | jq --raw-output 'keys[]'`
	do
		echo "setting value for: $key"
		curr_val=$(echo $VALS | jq .data | jq --raw-output .$key)
		export $key=$curr_val
	done
fi
# now load service account credentials
if [ -n $SERVICE_ACCOUNT_PATH ] ; then
	CREDS_VALS=`vault read -format=json $SERVICE_ACCOUNT_PATH`
	JSON_CONTENTS=`echo $CREDS_VALS | jq --raw-output .data`
	echo "setting value for GOOGLE_CLOUD_KEYFILE_JSON"
	export GOOGLE_CLOUD_KEYFILE_JSON=$(echo -n $JSON_CONTENTS)
	echo "setting value for GOOGLE_PRIVATE_KEY"
	export GOOGLE_PRIVATE_KEY=$(echo $CREDS_VALS | jq --raw-output .data.private_key)
	echo "setting value for GOOGLE_CLIENT_EMAIL"
	export GOOGLE_CLIENT_EMAIL=$(echo $CREDS_VALS | jq --raw-output .data.client_email)
	echo "setting value for GOOGLE_CLIENT_ID"
	export GOOGLE_CLIENT_ID=$(echo $CREDS_VALS | jq --raw-output .data.client_id)
	echo "setting value for GOOGLE_CLOUD_PROJECT"
	export GOOGLE_CLOUD_PROJECT=$(echo $CREDS_VALS | jq --raw-output .data.project_id)
fi
# boot portal once secrets are loaded
bin/boot_docker -e $PASSENGER_APP_ENV