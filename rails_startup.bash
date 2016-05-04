#!/bin/bash

cd /home/app/webapp
#openssl req -newkey rsa:4096 -days 365 -nodes -x509 \
#    -subj "/C=US/ST=Massachusetts/L=Cambridge/O=Broad Institute/OU=BITS DevOps/CN=localhost/emailAddress=bistline@broadinstitute.org" \
#    -keyout /etc/pki/tls/private/localhost.key \
#    -out /etc/pki/tls/certs/localhost.crt
#echo "*** MIGRATING DATABASE ***"
#bundle exec rake RAILS_ENV=$PASSENGER_APP_ENV db:create
#bundle exec rake RAILS_ENV=$PASSENGER_APP_ENV db:migrate
#echo "*** COMPLETED ***"
echo "*** CLEARING TMP CACHE ***"
sudo -u app -H bundle exec rake RAILS_ENV=$PASSENGER_APP_ENV tmp:clear
echo "*** COMPLETED ***"
if [[ $PASSENGER_APP_ENV = "production" ]]
then
    echo "*** PRECOMPILING ASSETS ***"
    rm -rf public/single_cell_demo/assets
    sudo -u app -H bundle exec rake RAILS_ENV=$PASSENGER_APP_ENV SECRET_KEY_BASE=$SECRET_KEY_BASE assets:precompile
    echo "*** COMPLETED ***"
fi

if [[ -e /home/app/webapp/bin/delayed_job ]]
then
    echo "*** STARTING DELAYED_JOB ***"
    sudo -u app -H bin/delayed_job restart $PASSENGER_APP_ENV -n 6
    echo "*** COMPLETED ***"
fi
