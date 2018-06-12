#! /bin/bash

# load_env_secrets.sh
#
# shell script to export environment variables from Vault secrets or a JSON configuration file and then boot portal
# requires the jq utility: https://stedolan.github.io/jq/ and vault: https://www.vaultproject.io

# usage error message
usage=$(
cat <<EOF

### shell script to load secrets from Vault and execute command ###
$0

[OPTIONS]
-p VALUE	set the path to the Vault configuration object
-s VALUE	set the path to the service account credentials object in Vault
-f VALUE	set the path to the local JSON configuration file (optional, is overridden by -p)
-c VALUE	command to execute after loading secrets (defaults to bin/boot_docker, please wrap command in 'quotes' to ensure proper execution)
-e VALUE	set the environment to boot the portal in (defaults to development)
-H COMMAND	print this text
EOF
)

# defaults
PASSENGER_APP_ENV="development"
COMMAND="bin/boot_docker"
while getopts "p:s:r:f:c:e:bH" OPTION; do
case $OPTION in
	p)
		VAULT_SECRET_PATH="$OPTARG"
		;;
	s)
		SERVICE_ACCOUNT_PATH="$OPTARG"
		;;
	r)
		READ_ONLY_SERVICE_ACCOUNT_PATH="$OPTARG"
		;;
	f)
		CONFIG_FILE_PATH="$OPTARG"
		;;
	c)
		COMMAND="$OPTARG"
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
if [ -z $SERVICE_ACCOUNT_PATH ] && [ -z $VAULT_SECRET_PATH ] ; then
	echo "You must supply the SERVICE_ACCOUNT_PATH [-c] & VAULT_SECRET_PATH [-p] (or CONFIG_PATH_PATH [-f]) to use this script."
	echo ""
	echo "$usage"
	exit 1
fi
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

# now load public read-only service account credentials
if [ -n $READ_ONLY_SERVICE_ACCOUNT_PATH ] ; then
	READ_ONLY_CREDS_VALS=`vault read -format=json $READ_ONLY_SERVICE_ACCOUNT_PATH`
	READ_ONLY_JSON_CONTENTS=`echo $READ_ONLY_CREDS_VALS | jq --raw-output .data`
	echo "setting value for READ_ONLY_GOOGLE_CLOUD_KEYFILE_JSON"
	export READ_ONLY_GOOGLE_CLOUD_KEYFILE_JSON=$(echo -n $READ_ONLY_JSON_CONTENTS)
	COMMAND=$COMMAND" -K /home/app/webapp/config/.read_only_service_account.json"
fi
# execute requested command
$COMMAND -e $PASSENGER_APP_ENV