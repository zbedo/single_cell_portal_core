#!/bin/bash

cd /home/app/webapp
echo "*** CLEARING TMP CACHE ***"
sudo -E -u app -H bin/rails RAILS_ENV=$PASSENGER_APP_ENV tmp:clear
echo "*** COMPLETED ***"
echo "*** ROLLING OVER LOGS ***"
ruby /home/app/webapp/bin/cycle_logs.rb
echo "*** COMPLETED ***"
if [[ $PASSENGER_APP_ENV = "production" ]] || [[ $PASSENGER_APP_ENV = "staging" ]]
then
    echo "*** PRECOMPILING ASSETS ***"
    sudo -E -u app -H bundle exec rails RAILS_ENV=$PASSENGER_APP_ENV SECRET_KEY_BASE=$SECRET_KEY_BASE assets:clean
    sudo -E -u app -H bundle exec rails RAILS_ENV=$PASSENGER_APP_ENV SECRET_KEY_BASE=$SECRET_KEY_BASE assets:precompile
    sudo -E -u app -H bundle exec rails RAILS_ENV=$PASSENGER_APP_ENV SECRET_KEY_BASE=$SECRET_KEY_BASE webpacker:install
    sudo -E -u app -H bundle exec rails RAILS_ENV=$PASSENGER_APP_ENV SECRET_KEY_BASE=$SECRET_KEY_BASE webpacker:compile
    echo "*** COMPLETED ***"
fi

echo "*** CREATING CRON ENV FILES ***"
echo "export PROD_DATABASE_PASSWORD=$PROD_DATABASE_PASSWORD" >| /home/app/.cron_env
echo "export SENDGRID_USERNAME=$SENDGRID_USERNAME" >> /home/app/.cron_env
echo "export SENDGRID_PASSWORD=$SENDGRID_PASSWORD" >> /home/app/.cron_env
echo "export MONGO_LOCALHOST=$MONGO_LOCALHOST" >> /home/app/.cron_env
echo "export SECRET_KEY_BASE=$SECRET_KEY_BASE" >> /home/app/.cron_env
if [[ -z $SERVICE_ACCOUNT_KEY ]]; then
	echo $GOOGLE_CLOUD_KEYFILE_JSON >| /home/app/.google_service_account.json
	chmod 400 /home/app/.google_service_account.json
	chown app:app /home/app/.google_service_account.json
	echo "export SERVICE_ACCOUNT_KEY=/home/app/.google_service_account.json" >> /home/app/.cron_env
else
	echo "export SERVICE_ACCOUNT_KEY=$SERVICE_ACCOUNT_KEY" >> /home/app/.cron_env
fi
if [[ -z $READ_ONLY_SERVICE_ACCOUNT_KEY ]] && [[ -n $READ_ONLY_GOOGLE_CLOUD_KEYFILE_JSON ]]; then
	echo "*** WRITING READ ONLY SERVICE ACCOUNT CREDENTIALS ***"
	echo $READ_ONLY_GOOGLE_CLOUD_KEYFILE_JSON >| /home/app/webapp/config/.read_only_service_account.json
	echo "export READ_ONLY_SERVICE_ACCOUNT_KEY=/home/app/webapp/config/.read_only_service_account.json" >> /home/app/.cron_env
	chown app:app /home/app/webapp/config/.read_only_service_account.json
elif [[ -n $READ_ONLY_SERVICE_ACCOUNT_KEY ]]; then
	echo "export READ_ONLY_SERVICE_ACCOUNT_KEY=$READ_ONLY_SERVICE_ACCOUNT_KEY" >> /home/app/.cron_env
else
	echo "*** NO READONLY SERVICE ACCOUNT DETECTED -- SOME FUNCTIONALITY WILL BE DISABLED ***"
fi
chmod 400 /home/app/.cron_env
chown app:app /home/app/.cron_env
echo "*** COMPLETED ***"

echo "*** RUNNING PENDING MIGRATIONS ***"
sudo -E -u app -H bin/rake RAILS_ENV=$PASSENGER_APP_ENV db:migrate
echo "*** COMPLETED ***"

if [[ ! -d /home/app/webapp/tmp/pids ]]
then
	echo "*** MAKING TMP DIR ***"
	sudo -E -u app -H mkdir -p /home/app/webapp/tmp/pids
	echo "*** COMPLETED ***"
fi
echo "*** STARTING DELAYED_JOB ***"
sudo -E -u app -H bin/delayed_job start $PASSENGER_APP_ENV -n 4
echo "*** ADDING CRONTAB TO CHECK DELAYED_JOB ***"
echo "*/15 * * * * . /home/app/.cron_env ; /home/app/webapp/bin/job_monitor.rb -e=$PASSENGER_APP_ENV >> /home/app/webapp/log/cron_out.log 2>&1" | crontab -u app -
echo "*** COMPLETED ***"

echo "*** ADDING API HEALTH CRONTAB ***"
(crontab -u app -l ; echo "*/5 * * * * . /home/app/.cron_env ; cd /home/app/webapp/; /home/app/webapp/bin/rails runner -e $PASSENGER_APP_ENV \"AdminConfiguration.check_api_health\" >> /home/app/webapp/log/cron_out.log 2>&1") | crontab -u app -
echo "*** COMPLETED ***"

echo "*** ADDING CRONTAB TO REINDEX DATABASE ***"
(crontab -u app -l ; echo "@daily . /home/app/.cron_env ; cd /home/app/webapp/; bin/bundle exec rake RAILS_ENV=$PASSENGER_APP_ENV db:mongoid:create_indexes >> /home/app/webapp/log/cron_out.log 2>&1") | crontab -u app -
echo "*** COMPLETED ***"

echo "*** ADDING CRONTAB TO DELETE QUEUED STUDIES & FILES ***"
if [[ $PASSENGER_APP_ENV = "development" ]]
then
	(crontab -u app -l ; echo "*/5 * * * * . /home/app/.cron_env ; cd /home/app/webapp/; /home/app/webapp/bin/rails runner -e $PASSENGER_APP_ENV \"Study.delete_queued_studies\" >> /home/app/webapp/log/cron_out.log 2>&1") | crontab -u app -
	(crontab -u app -l ; echo "*/5 * * * * . /home/app/.cron_env ; cd /home/app/webapp/; /home/app/webapp/bin/rails runner -e $PASSENGER_APP_ENV \"StudyFile.delete_queued_files\" >> /home/app/webapp/log/cron_out.log 2>&1") | crontab -u app -
	(crontab -u app -l ; echo "*/5 * * * * . /home/app/.cron_env ; cd /home/app/webapp/; /home/app/webapp/bin/rails runner -e $PASSENGER_APP_ENV \"UserAnnotation.delete_queued_annotations\" >> /home/app/webapp/log/cron_out.log 2>&1") | crontab -u app -
else
	(crontab -u app -l ; echo "0 1 * * * . /home/app/.cron_env ; cd /home/app/webapp/; /home/app/webapp/bin/rails runner -e $PASSENGER_APP_ENV \"Study.delete_queued_studies\" >> /home/app/webapp/log/cron_out.log 2>&1") | crontab -u app -
	(crontab -u app -l ; echo "0 1 * * * . /home/app/.cron_env ; cd /home/app/webapp/; /home/app/webapp/bin/rails runner -e $PASSENGER_APP_ENV \"StudyFile.delete_queued_files\" >> /home/app/webapp/log/cron_out.log 2>&1") | crontab -u app -
	(crontab -u app -l ; echo "0 1 * * * . /home/app/.cron_env ; cd /home/app/webapp/; /home/app/webapp/bin/rails runner -e $PASSENGER_APP_ENV \"UserAnnotation.delete_queued_annotations\" >> /home/app/webapp/log/cron_out.log 2>&1") | crontab -u app -
fi
echo "*** COMPLETED ***"

echo "*** ADDING DAILY ADMIN DISK MONITOR EMAIL ***"
(crontab -u app -l ; echo "0 3 * * * . /home/app/.cron_env ; cd /home/app/webapp/; /home/app/webapp/bin/rails runner -e $PASSENGER_APP_ENV \"SingleCellMailer.daily_disk_status.deliver_now\" >> /home/app/webapp/log/cron_out.log 2>&1") | crontab -u app -
echo "*** COMPLETED ***"

echo "*** ADDING DAILY STORAGE SANTIY CHECK ***"
(crontab -u app -l ; echo "30 3 * * * . /home/app/.cron_env ; cd /home/app/webapp/; /home/app/webapp/bin/rails runner -e $PASSENGER_APP_ENV \"Study.delay.storage_sanity_check\" >> /home/app/webapp/log/cron_out.log 2>&1") | crontab -u app -
echo "*** COMPLETED ***"

echo "*** ADDING DAILY RESET OF USER DOWNLOAD QUOTAS ***"
(crontab -u app -l ; echo "@daily . /home/app/.cron_env ; cd /home/app/webapp/; /home/app/webapp/bin/rails runner -e $PASSENGER_APP_ENV \"User.update_all(daily_download_quota: 0)\" >> /home/app/webapp/log/cron_out.log 2>&1") | crontab -u app -
echo "*** COMPLETED ***"

echo "*** CLEARING CACHED USER OAUTH TOKENS ***"
/home/app/webapp/bin/rails runner -e $PASSENGER_APP_ENV "User.update_all(refresh_token: nil, access_token: nil)"
echo "*** COMPLETED ***"

echo "*** ADDING REPORTING CRONS ***"
(crontab -u app -l ; echo "5 0 * * Sun . /home/app/.cron_env ; cd /home/app/webapp/; /home/app/webapp/bin/rails runner -e $PASSENGER_APP_ENV \"ReportTimePoint.weekly_returning_users\" >> /home/app/webapp/log/cron_out.log 2>&1") | crontab -u app -
echo "*** COMPLETED ***"

echo "*** SENDING RESTART NOTIFICATION ***"
sudo -E -u app -H /home/app/webapp/bin/rails runner -e $PASSENGER_APP_ENV "AdminConfiguration.restart_notification"