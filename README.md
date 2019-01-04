# SINGLE CELL PORTAL README

## SETUP

This application is built and deployed using [Docker](https://www.docker.com), specifically native 
[Docker for Mac OSX](https://docs.docker.com/docker-for-mac/). Please refer to their online documentation for instructions 
on installing Docker.

## BUILDING THE DOCKER IMAGE

Once all source files are checked out and Docker has been installed and your VM configured, open a terminal window and 
execute the following steps:

1. Navigate to the project directory
1. Build the Single Cell Portal image: `docker build -t single_cell_docker -f Dockerfile .`

This will start the automated process of building the Docker image for running the portal.  The image is built off of the 
[Passenger-docker baseimage](https://github.com/phusion/passenger-docker) and comes with Ruby, Nginx, and Passenger by 
default, with additional packages added to the [Broad Institute KDUX Rails baseimage](https://hub.docker.com/r/broadinstitute/kdux-rails-baseimage/) 
which pulls from the original baseimage.  The extended image contains ImageMagick, and self-signed SSL certificats & CA 
Authority for doing local development in https.

*If this is your first time building the image, it may take several minutes to download and install everything.*

## BEFORE RUNNING THE CONTAINER

Since this project utilizes native Docker for Mac OSX, any resources on the host machine cannot be reached by the running 
container (specifically, any database resources). Therefore, we will need to deploy a database container using Docker as 
well.  This project uses [MongoDB](https://hub.docker.com/_/mongo/) as the primary datastore.

First, create a directory somewhere on your computer in which to store the raw database content (it doesn't matter where 
as long as it has `rw` permissions, but preferably it would be inside your home directory).

To deploy the database container:

1. Pull the image: `docker pull mongo`
1. Navigate to the project directory
1. Run the helper script to start the DB container: `bin/boot_mongo -d (path to data store directory)`

Note: Once the container has been run once, you can stop & restart it using: `docker stop mongodb` or `docker restart mongodb`

## LOCAL DEVELOPMENT OR DEPLOYING A PRIVATE INSTANCE

If you are not part of the Single Cell Portal development team and are trying to use the portal locally or deploying a 
private instance of the Single Cell Portal (i.e. not any Broad Institute instance), there are a few extra steps that need 
to be taken before the portal is configured and ready to use:

* **Create a GCP project**: Even if you are deploying locally or in a private cluster, the portal requires a Google Cloud 
Plaform project in order to handle OAuth callbacks and service account credentials.  To create your project:
  * Visit https://console.developers.google.com
  * Click 'Select a project' in the top lefthand corner and click the + button
  * Name your new project and save

* **OAuth Credentials**: Once your project is created, you will need to create an OAuth Client ID in order to allow users 
to log in with their Google accounts.  To do so:
  * Log into your new GCP project
  * Click the navigation menu in the top left and select 'APIs & Services' > 'Credentials'
  * Click 'Create Credentials' > 'OAuth Client ID'
  * Select 'Web Application', and provide a name
  * For 'Authorized Javascript Origins', enter the following:
    * `https://(your hostname)/single_cell`
  * For 'Authorized redirect URIs', enter the following: 
    * `https://(your hostname)/single_cell/users/auth/google_oauth2/callback`
    * `	https://(your hostname)/single_cell/api/swagger_docs/oauth2`
  * Save the client id
  * You will also want to create a second OAuth Client ID to use in local development, using `localhost` as the hostname

* **Whitelisting your OAuth Audience**
  * Once you have exported your OAuth credentials, you will need to have your client id whitelisted to allow it to make 
  authenticated requests into the FireCloud API as per [OpenID Connect 1.0](http://openid.net/specs/openid-connect-core-1_0.html#IDTokenValidation)
    *  Send an email to **dsp-devops@broadinstitute.org** with your OAuth2 client ID(s) so it can be added to the whitelist

* **GCP Service Account keys**: Regardless of where the portal is deployed, it requires a Google Cloud Platform Service 
Account in order to make authenticated calls into FireCloud and Google Cloud Storage.  Therefore, you must export the 
default service account key.  See https://developers.google.com/identity/protocols/OAuth2ServiceAccount for more information 
about service accounts.  To export the credentials:
	*  Log into your new GCP project
	*  Click the navigation menu in the top left and select 'IAM & Admin	' > 'Service Accounts'
	*  On entry 'Compute Engine default service account', click the 'Options' menu (far right) and select 'Create key'
	*  Select 'JSON' and export and save the key locally
	*  Additionally, a 'read-only' service account is now used for streaming GCS assets to the client in some instances, 
	so create a second service account and set the role to 'Storage Object Viewer' (see READ-ONLY SERVICE ACCOUNT at the 
	bottom for a more detailed explanation on the role of this service account)
	*  Save this additional account locally next to the main service account.

* **Enable GCP APIs**: The following Google Cloud Platform APIs must be enabled:
	* Google Compute Engine API
	* Google Cloud APIs
	* Google Cloud Billing API
	* Google Cloud Storage JSON API
	* Google+ API

* **Registering your Service Account as a FireCloud user**: Once you have configured and booted your instance of the portal, 
you will need to register your service account as a FireCloud user in order to create a billing project and create studies.  
To do so:
	* Launch an instance of your portal (see [RUNNING THE CONTAINER](#running-the-container) below)
	* Create an admin user account (see [ADMIN USER ACCOUNTS](#admin-user-accounts) below)
	* Log in with the admin account, and select 'Admin Configurations' from the profile menu (top righthand corner)
	* At the bottom of the page, in the 'Other Tasks' dropdown, select 'Manage Main Service Account FireCloud Registration' 
	and click 'Execute Task'
	* Fill out all form fields and submit
	* This must be done for both the 'main' and 'read-only' service accounts

* **Creating a FireCloud Project**: Once your OAuth audience has been whitelisted, and before you can create studies, you 
will need to create a FireCloud project that will own all the workspaces created in the portal. To do this:
	* Create a [Google Billing Project](https://software.broadinstitute.org/firecloud/documentation/article?id=9762).
	* Using the same Google account that owns the billing project, log into the portal and select 'My Billing Projects' from the profile menu.
	* Click 'New Billing Project' at the bottom of the page
		* Select your newly-created billing account
		* Provide a name for your project (no spaces allowed)
		* Click 'Create Billing Project'


## RUNNING THE CONTAINER

Once the image has successfully built, all registration/configuration steps have been completed, use the following command 
to start the container:

    bin/boot_docker -u (sendgrid username) -P (sendgrid password) -k (service account key path) -K (read-only service account key path) -o (oauth client id) -S (oauth client secret) -y (Sentry DSN)

This sets up several environment variables in your shell and then runs the following command:

    docker run --rm -it --name $CONTAINER_NAME -p 80:80 -p 443:443 -p 587:587 --link mongodb:mongodb -h localhost -v $PROJECT_DIR:/home/app/webapp:rw -e PASSENGER_APP_ENV=$PASSENGER_APP_ENV -e MONGO_LOCALHOST=$MONGO_LOCALHOST -e SENDGRID_USERNAME=$SENDGRID_USERNAME -e SENDGRID_PASSWORD=$SENDGRID_PASSWORD -e SECRET_KEY_BASE=$SECRET_KEY_BASE -e SERVICE_ACCOUNT_KEY=$SERVICE_ACCOUNT_KEY -e OAUTH_CLIENT_ID=$OAUTH_CLIENT_ID -e OAUTH_CLIENT_SECRET=$OAUTH_CLIENT_SECRET -e SENTRY_DSN=$SENTRY_DSN -e GA_TRACKING_ID=$GA_TRACKING_ID single_cell_docker

The container will then start running, and will execute its local startup scripts that will configure the application automatically.

You can also run the `bin/boot_docker` script in help mode by passing `-H` to print the help text which will show you how 
to pass specific values to the above env variables.  *Note: running the shortcut script with an environment of 'production' 
will cause the container to spawn headlessly by passing the `-d` flag, rather than `--rm -it`.*

### BROAD INSTITUTE CONFIGURATION

Broad Institute project members can load all project secrets from Vault and boot the portal directly by using the 
`bin/load_env_secrets.sh` script, thereby skipping all of the configuration/registration steps in [DEPLOYING A PRIVATE INSTANCE](#local-development-or-deploying-a-private-instance)

    bin/load_env_secrets.sh -p (path/to/service/account.json) -s (path/to/portal/config) -r (path/to/readonly/service/account.json) -e (environment)

This script takes four parameters:

1.  **VAULT_SECRET_PATH** (passed with -p): Path to portal configuration JSON inside Vault.
1.  **SERVICE_ACCOUNT_PATH** (passed with -c): Path to GCP main service account configuration JSON inside Vault.
1.  **READ_ONLY_SERVICE_ACCOUNT_PATH** (passed with -c): Path to GCP read-only service account configuration JSON inside Vault.
1.  **PASSENGER_APP_ENV** (passed with -e; optional): Environment to boot portal in.  Defaults to 'development'.

The script requires two command line utilities: [vault](https://www.vaultproject.io) and [jq](https://stedolan.github.io/jq/). 
Please refer to their respective sites for installation instructions.

### DOCKER RUN COMMAND ENVIRONMENT VARIABLES
There are several variables that need to be passed to the Docker container in
order to run properly:
1. **CONTAINER_NAME** (passed with --name): This names your container to whatever you want.  This is useful when linking 
containers.
1. **PROJECT_DIR** (passed with -v): This mounts your local working directory inside the Docker container.  Makes doing 
local development via hot deployment possible.
1. **PASSENGER_APP_ENV** (passed with -e): The Rails environment you wish to load.  Can be either development, test, or 
production (default is development).
1. **MONGO_LOCALHOST** (passed with -e): Name of the container running MongoDB.  Even though our two containers are linked, 
this needs to be set to allow Rails to communicate with the database.
1. **SENDGRID_USERNAME** (passed with -e): The username associated with a Sendgrid account (for sending emails).
1. **SENDGRID_PASSWORD** (passed with -e): The password associated with a Sendgrid account (for sending emails).
1. **SECRET_KEY_BASE** (passed with -e): Sets the Rails SECRET_KEY_BASE environment variable, used mostly by Devise in authentication for cookies.
1. **SERVICE_ACCOUNT_KEY** (passed with -e): Sets the SERVICE_ACCOUNT_KEY environment variable, used for making authenticated 
API calls to FireCloud & GCP.
1. **READ_ONLY_SERVICE_ACCOUNT_KEY** (passed with -e): Sets the READ_ONLY_SERVICE_ACCOUNT_KEY environment variable, used 
for making authenticated API calls to GCP for streaming assets to the browser.
1. **OAUTH_CLIENT_ID** (passed with -e): Sets the OAUTH_CLIENT_ID environment variable, used for Google OAuth2 integration.
1. **OAUTH_CLIENT_SECRET** (passed with -e): Sets the OAUTH_CLIENT_SECRET environment variable, used for Google OAuth2 
1. **SENTRY_DSN** (passed with -e): Sets the SENTRY_DSN environment variable, for error reporting to [Sentry](https://sentry.io/)
integration.
1. **GA_TRACKING_ID** (passed with -e): Sets the GA_TRACKING_ID environment variable for tracking usage via 
[Google Analytics](https://analytics.google.com) if you have created an app ID.
1. **PROD_DATABASE_PASSWORD** (passed with -e, for production deployments only): Sets the prod database password for accessing
the production database instance.  Only needed when deploying the portal in production mode.  See <code>config/mongoid.yml</code>
for more configuration information regarding the production database.


### RUN COMMAND IN DETAIL
The run command explained in its entirety:
* **--rm:** This tells Docker to automatically clean up the container after exiting.
* **-it:** Leaves an interactive shell running in the foreground where the output of Nginx can be seen.
* **--name CONTAINER_NAME:** This names your container to whatever you want.  This is useful when linking other Docker 
containers to the portal container, or when connecting to a running container to check logs or environment variables.  
The default is **single_cell**.
* **-p 80:80 -p 443:443 -p 587:587:** Maps ports 80 (HTTP), 443 (HTTPS), and 587 (smtp) on the host machine to the 
corresponding ports inside the Docker container.
* **--link mongodb:mongodb**: Connects our webapp container to the mongodb container, creating a virtual hostname inside 
the single_cell_docker container called mongodb.
* **-v [PROJECT_DIR]/:/home/app/webapp:** This mounts your local working directory inside the running Docker container 
in the correct location for the portal to run.  This accomplishes two things:
	* Enables hot deployment for local development
	* Persists all project data past destruction of Docker container (since we're running with --rm), but not system-level 
	log or tmp files.
* **-e PASSENGER_APP_ENV=[RAILS_ENV]:** The Rails environment.  Will default to development, so if you're doing a 
production deployment, set this accordingly.
* **-e MONGO_LOCALHOST= [MONGO_LOCALHOST]:** Name of the container running MongoDB.  Even though our two containers are 
linked, this needs to be set to allow Rails to communicate with the database.
* **-e SENDGRID_USERNAME=[SENDGRID_USERNAME] -e SENDGRID_PASSWORD=[SENDGRID_PASSWORD]:** The credentials for Sendgrid to 
send emails. Alternatively, you could decide to not use Sendgrid and configure the application to use a different SMTP 
server (would be done inside your environment's config file).
* **-e SECRET_KEY_BASE=[SECRET_KEY_BASE]:** Setting the SECRET_KEY_BASE variable is necessary for creating secure cookies 
for authentication.  This variable automatically resets every time we restart the container.
* **-e SERVICE_ACCOUNT_KEY=[SERVICE_ACCOUNT_KEY]:** Setting the SERVICE_ACCOUNT_KEY variable is necessary for making 
authenticated API calls to FireCloud and GCP.  This should be a file path **relative to the app root** that points to the 
JSON service account key file you exported from GCP.
* **-e READ_ONLY_SERVICE_ACCOUNT_KEY=[READ_ONLY_SERVICE_ACCOUNT_KEY]:** Setting the READ_ONLY_SERVICE_ACCOUNT_KEY variable 
is necessary for making authenticated API calls to GCP.  This should be a file path **relative to the app root** that points 
to the JSON read-only service account key file you exported from GCP.
* **-e OAUTH_CLIENT_ID=[OAUTH_CLIENT_ID] -e OAUTH_CLIENT_SECRET=[OAUTH_CLIENT_SECRET]:** Setting the OAUTH_CLIENT_ID and
OAUTH_CLIENT_SECRET variables are necessary for allowing Google user authentication.  For instructions on creating OAuth 
2.0 Client IDs, refer to the [Google OAuth 2.0 documentation](https://support.google.com/cloud/answer/6158849).
* **-e SENTRY_DSN=[SENTRY_DSN]:** Sets the SENTRY_DSN environment variable for error reporting to [Sentry](https://sentry.io/)
* **-e GA_TRACKING_ID=[GA_TRACKING_ID]:** Sets the GA_TRACKING_ID environment variable for tracking usage via 
[Google Analytics](https://analytics.google.com)
* **single_cell_docker**: This is the name of the image we created earlier. If you chose a different name, please use 
that here.

### ADMIN USER ACCOUNTS
The Single Cell Portal has the concept of a 'super-admin' user account, which will allow portal admins to view & edit any 
studies in the portal for QA purposes, as well as receive certain admin-related emails.  This can only be enabled manually 
through the console.

To create an admin user account:
* Start the portal locally (or ssh into production VM)
* Create a user account normally by logging in through the UI
* Connect to the running portal container: `docker exec -it single_cell bash`
* Enter the Rails console: `rails console`
* Query for the desired user account: `user = User.find_by(email: '<email address here>')`
* Set the admin flag to true: `user.update(admin: true)`

## TESTS

### UI REGRESSION SUITE

#### TEST SETUP

All user interface tests are handle through [Selenium Webdriver](http://www.seleniumhq.org/docs/03_webdriver.jsp) and 
[Chromedriver](https://sites.google.com/a/chromium.org/chromedriver/) and are run against a regular instance of the portal, 
usually in development mode. The test suite is run from the `test/ui_test_suite.rb` script.

Due to the nature of Docker, the tests cannot be run from inside the container as the Docker container cannot connect back 
to Chromedriver and the display from inside the VM.  As a result, the UI test suite has no knowledge of the Rails environment 
or application stack. Therefore, you will need to have a minimal portal environment enabled outside of Docker. The minumum 
requirements are as follows:

* Ruby 2.5.1, preferably mangaged through [RVM](https://rvm.io/) or [rbenv](https://github.com/rbenv/rbenv)
* Gems: [rubygems](https://github.com/rubygems/rubygems), [test-unit](http://test-unit.github.io), 
[selenium-webdriver](https://github.com/SeleniumHQ/selenium/tree/master/rb) (see Gemfile.lock for version requirements)
* Google Chrome along with 2 Google accounts, one of which needs to be a portal admin account (see 
[ADMIN USER ACCOUNTS](#admin-user-accounts) above)
* [Chromedriver](http://chromedriver.chromium.org/)
* FireCloud accounts for both Google accounts (see [FIRECLOUD INTEGRATION](#firecloud-integration) below)


#### RUNNING UI TESTS

To begin the test suite, launch an instance of the portal in development mode and run the following command in another 
shell in the portal root directory:

    ruby test/ui_test_suite.rb -- -e=(email account #1) -s=(email account #2) -p='(email account #1 password)' -P='(email account #2 password)'

Passwords are required as all portal accounts are actual Google accounts, so we pass in passwords at runtime to allow 
the script to authenticate as the specified user.  Passwords are only stored temporarily in-memory and are not persisted 
to disk at any point (other than your shell history, which you can clear with `history -c` if you so desire.)

Paths to the chromedriver binary and your profile download directory can also be configured with the `-c` and `-d` flags, 
respectively.

In addition to the above configuration options, it is possible to run the UI test suite against a deployed instance of the 
portal by passing in the base portal URL via the `-u` flag.  Note that all of the above user requirements must be met for 
whatever instance you test.

There are 3 main groups of tests: admin (study creation & editing), front-end (study data searching & visualization), and 
cleanup (removing studies created during testing).  You can run groups discretely by passing `-n /pattern/` to the test 
suite as follows:

To run all admin tests:

    ruby test/ui_test_suite.rb -n /admin/ -- (rest of test parameters)

To run all front-end tests:

    ruby test/ui_test_suite.rb -n /front-end/ -- (rest of test parameters)

This can also be used to run smaller groups by refining the regular expression to match only certain names of tests.  For 
example, to run all front-end tests that deal with file downloads:

    ruby test/ui_test_suite.rb -n /front-end.*download/ -- (rest of test parameters)

You can also run a single test by passing the entire test name as the name parameter:

    ruby test/ui_test_suite.rb -n 'test: admin: create a study' -- (rest of test parameters)

Similarly, you can pass `--ignore-name /pattern/` to run all tests that do not match the given pattern:

    ruby test/ui_test_suite.rb --ignore-name /billing-accounts/ -- (rest of test parameters)

More information on usage & test configuration can be found in the comments at the top of the test suite.

### UNIT & INTEGRATION TESTS
There is a smaller unit & integration test framework for the Single Cell Portal that is run using the built-in test Rails 
harness, which uses [Test::Unit](https://github.com/test-unit/test-unit) and [minitest-rails](https://github.com/blowmage/minitest-rails). 
These unit & integration tests only cover specific functionality that requires integration with portal models and methods, 
and therefore cannot be run from the UI test suite.

These tests are run automatically after setting up the application and seeding the test database.  This is 
handled via a shell script `bin/run_unit_tests.sh` that will precompile any needed assets (for performance), seed the 
test database, run the tests, and then destroy all created records to clean up after running.

To run the unit & integration test suite, the `boot_docker` script can be used:

    bin/boot_docker -e test -k (service account key path) -K (read-only service account path)

This will boot a new instance of the portal in test mode and run all associated tests, *not including the UI test suite*.

It is also possible to run individual tests suites by passing the following parameters to `boot_docker`. To run all tests 
in a single suite:

    bin/boot_docker -e test -k (service account key path) -K (read-only service account path) -t (relative/path/to/tests.rb)

For instance, to run the FireCloudClient integration test suite:

    bin/boot_docker -e test -t test/integration/fire_cloud_client_test.rb (... rest of parameters)

You can also only run a subset of matching tests by passing -R /regexp/.  The following example would run all tests with 
the word 'workspace' in their test name:

    bin/boot_docker -e test -t test/integration/fire_cloud_client_test.rb -R /workspace/ (... rest of parameters)

It is also possible to pass a fully-qualified single-quoted name to run only a single test.  The following example would 
run only the test called `'test_workspaces'` in `test/integration/fire_cloud_client_test.rb`

    bin/boot_docker -e test -t test/integration/fire_cloud_client_test.rb -R 'test_workspaces' (... rest of parameters)

## GOOGLE DEPLOYMENT

### PRODUCTION

The official production Single Cell Portal is deployed in Google Cloud Platform.  The project name is **broad-singlecellportal**. 
Only Broad Institute Single Cell Portal team members have access to this instance.  If you are a collaborator and require 
access, please email [single_cell_portal@broadinstitute.org](mailto:single_cell_portal@broadinstitute.org).

To access the production instance for maintenance purposes:
* Go to the [broad-singlecellportal](https://console.cloud.google.com/home/dashboard?project=broad-singlecellportal) GCP page
* Select "Compute Engine" from the top-left nav dropdown
* At the bottom of the page is the entry for the production VM (called singlecell-production)
* Click the SSH button under the Connect heading (this will launch an SSH tunnel in a browser window)
* Once connected, switch to root via `sudo -i`.
* Change directory to where the portal is running: `cd /home/docker-user/single_cell_portal`
* Switch to the Docker user: `sudo -u docker-user -Hs`
* Get latest source code from GitHub: `git pull origin master`
* Exit Docker user to return to root: `exit`
* Ensure no uploads or parses are occuring: `tail -n 1000 log/production.log`
* Put the portal in maintenance mode: `bin/enable_maintenance.sh on`
* Stop the portal: `docker stop single_cell`
* Remove the container instance: `docker rm single_cell`
* Launch a new instance of the portal with the updated container:


    bin/boot_docker -u (sendgrid username) -P (sendgrid password) -e production -p (prod database password) -h (production hostname) -k (service account key path) -K (read-only service account key path) -o (oauth client id) -S (oauth client secret) -y (Sentry DSN)`

* View Docker logs: `docker logs -f single_cell`
* Once Nginx is running again (i.e. you see "Passenger core online" in Docker logs), take off maintanence mode via `bin/enable_maintenance.sh off`
* Check https://portals.broadinstitute.org/single_cell to verify that deployment succeeded

If you are deploying your own production instance in a different project, the following VM/OS configurations are recommended:
* VM: n1-highmem-4 (4 vCPUs, 26 GB memory)
* OS: Ubuntu 15.10 (Wily) or later
* Disks: Two standard persistent disks, one for the portal/database, and a second for upload tmp space mounted at `[/path/to/portal/root]/data`

For more information on formatting and mounting additional persistent disks to a GCP VM, please read the 
[GCP Documentation](https://cloud.google.com/compute/docs/disks/add-persistent-disk#formatting).

#### PRODUCTION DOCKER COMMANDS

* To bounce the portal: `docker restart single_cell` 
* To stop the portal: `docker stop single_cell` 
* To remove the portal container: `docker rm single_cell` 
* To connect to the running portal container: `docker exec -it single_cell bash`

If you have pulled changes from source that require re-building the container, you will need to follow the checklist above 
in the [PRODUCTION](#production) section.

**You will need to rebuild the docker image if you do any of the following:**
* Edit the Dockerfile
* Edit any scripts or configuration files listed in the Dockerfile:
  * Gemfile (including Gemfile.lock if versions have changed)
  * set_user_permissions.bash
  * rails_startup.bash
  * generate_dh_parameters.bash
  * nginx.conf
  * webapp.conf

When you launch a new instance of the portal, you should get a response that is looks like a long hexadecimal string - 
this is the instance ID of the new container.  Once the container is running, you can connect to it with the `docker exec` 
command and perform various Rails-specific actions, like:

* Re-index the database: `bin/rake RAILS_ENV=production db:mongoid:create_indexes`
* Launch the Rails console (to inspect database records, for instance): `bin/rails console -e production`


### STAGING

There is also a staging instance of the Single Cell Portal used for testing new functionality in a production-like setting. 
This is running inside the same project on the `singlecell-staging` VM.  The staging instance URL is https://single-cell-staging.broadinstitute.org/single_cell

The run command for staging is identical to that of production, with the exception of passing `-e staging` as the environment, 
and any differing values for hostnames/client secrets/passwords as needed.

*Note: This instance is usually turned off to save on compute costs, so there is no expectation that it is up at any given time*

### FIRECLOUD INTEGRATION

The Single Cell Portal stores uploaded study data files in [FireCloud](https://software.broadinstitute.org/firecloud/) 
workspaces, which in turn store data in GCP buckets.  This is all managed through a GCP service account which in turn 
owns all portal workspaces and manages them on behalf of portal users.  All portal-related workspaces are within the 
`single-cell-portal` namespace, which should be noted is a separate project from the one the portal operates out of.

When a study is created through the portal, a call is made to the FireCloud API to provision a workspace and set the ACL 
to allow owner access to the user who created the study, and read/write access to any designated shares.  Every FireCloud 
workspace comes with a GCP storage bucket, which is where all uploaded files are deposited.  No ACLs are set on individual 
files as all permissions are inherited from the workspace itself.  Files are first uploaded temporarily locally to the 
portal (so that they can be parsed if needed) and then sent to the workspace bucket in the background after uploading and 
parsing have completed.

If a user has not signed up for a FireCloud account, they will receive and invitation email from FireCloud asking them to 
complete their registration.  While they will be able to interact with their study/data through the portal without completing 
their registration, they will not be able to load their FireCloud workspace or access the associated GCP bucket until they 
have done so.

Deleting a study will also delete the associated workspace, unless the user specifies that they want the workspace to be 
persisted. New studies can also be initialized from an existing workspace (specified by the user during creation) which will 
synchronize all files and permissions.

## OTHER FEATURES

### ADMIN CONTROL PANEL, DOWNLOAD QUOTAS & ACCESS REVOCATION

All portal users are required to authenticate before downloading data as we implement daily per-user quotas.  These are 
configurable through the admin control panel which can be accessed only by portal admin accounts (available through the 
profile menu or at /single_cell/admin).

There are currently 7 configuration actions:

* Daily download quota limit (defaults to 2 terabytes, but is configurable to any amount, including 0)
* Manage FireCloud access (can disable local access, compute access, or all access)
* Unlock orphaned jobs (any background jobs that were running during a portal restart are locked until this option is used)
* Refresh API clients (force the FireCloudClient class to renew all access tokens)
* Manage both service account FireCloud profiles (register or update the FireCloud profile associated with the main & 
readonly portal service accounts).
* See the current FireCloud API status (for all services)
* Synchronize the portal user group (if set, will add all users to user group)


#### READ-ONLY SERVICE ACCOUNT

The read-only service account is a GCP service account that is used to grant access to GCS objects from 'public' studies 
so that they can be rendered client-side for the user.  Normally, a user would not have access to these objects directly 
in GCS as access is federated by the main service account on public studies (private studies have explicit grants, and 
therefore user access tokens are used).  However, access tokens granted from the main service account would have project 
owner permissions, so they cannot be used safely in the client.  Therefore, a read-only account is used in this instance 
for operational security.

This account is not required for main portal functionality to work, but certain visualizations (Ideogram.js & IGV.js) 
will not be enabled unless this account is enabled.

To enable the read-only service account:

1. Create a new service account in your GCP project and grant it 'Storage Object Viewer' permission (see 'GCP Service 
Account keys' under [DEPLOYING A PRIVATE INSTANCE](#local-development-or-deploying-a-private-instance) for more information)

1. Export the JSON credentials to a file and save inside the portal home directory.
1. When booting your instance (via `bin/boot_docker`), make sure to pass `-K (/path/to/readonly/credentials.json)`
1. Once the portal is running, navigate to the Admin Control Panel with an admin user account
1. Select 'Manage Read-Only Service Account FireCloud Registration' from the 'Other Tasks' menu and click 'Execute'
1. Fill out all form fields and submit.
1. Once your new service account is registered, create a Config Option of the type 'Read-Only Access Control'
1. Set the type of value to 'Boolean', and set the value to 'Yes', and save


This will have the effect of adding shares to all public studies in your instance of the portal for the read-only service 
account with 'View' permission.  This will then enable the portal to stream certain kinds of files (BAM files, for instance) 
back to the client for visualization without the need for setting up and external proxy server.

To revoke this access, simply edit the configuration setting and set the value
to 'No'.

#### FIRECLOUD ACCESS SETTINGS

Disabling all FireCloud access is achieved by revoking all access to studies directly in FireCloud and using the portal 
permission map (study ownership & shares) as a backup cache.  This will prevent anyone from downloading data either through 
the portal or directly from the workspaces themselves.  This will have the side effect of disallowing any edits to studies 
while in effect, so this feature should only be used as a last resort to curtail runaway downloads.  While access is disabled, 
only the portal service account will have access to workspaces.

Disabling compute access will set all user access permissions to READER, thus disabling computes.

Disabling local access does not alter FireCloud permissions, but prevents users from accessing the 'My Studies' page and 
uploading data through the portal.  Downloads are still enabled, and normal front-end actions are unaffected.  

Re-enabling FireCloud access will restore all permissions back to their original state.

### MAINTENANCE MODE

The production Single Cell portal has a defined maintenance window every **Thursday from 12-2PM EST**.  To minimize user 
dispruption when doing updates during that window (or hot fixes any other time) the portal has a 'maintenance mode' feature 
that will return a 503 and redirect all incoming traffic to a static maintenance HTML page.

To use this feature, run the `bin/enable_maintenance.sh [on/off]` script accordingly.
