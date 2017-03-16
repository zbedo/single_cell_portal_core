class FireCloudClient < Struct.new(:access_token, :api_root, :storage, :expires_at)

	# Class that wraps API calls to both FireCloud and Google Cloud Storage to manage the CRUDing of both FireCloud workspaces
	# and files inside the associated GCP storage buckets
	#
	# Uses the gems googleauth (for generating access tokens), google-cloud-storage (for bucket/file access),
	# and rest-client (for HTTP calls)

	## CONSTANTS
	# base url for all API calls
	BASE_URL = 'https://api.firecloud.org'
	# default auth scopes
	GOOGLE_SCOPES = %w(https://www.googleapis.com/auth/userinfo.profile https://www.googleapis.com/auth/userinfo.email)
	# constant used for retry loops in process_request
	MAX_RETRY_COUNT = 3
	# namespace used for all FireCloud project workspaces
	PORTAL_NAMESPACE = 'single-cell-portal'
	# location of Google service account JSON (must be absolute path to file)
	SERVICE_ACCOUNT_KEY ||= ENV['SERVICE_ACCOUNT_KEY'] || File.absolute_path(Rails.root.join('config', 'broad-singlecellportal-d5dad9c8d7db.json'))
	# Permission values allowed for ACLs
	WORKSPACE_PERMISSIONS = ['OWNER', 'READER', 'WRITER', 'NO ACCESS']

	## CONSTRUCTOR
	#
	# initialize is called after instantiating with FireCloudClient.new
	# will set the access token, FireCloud api url root and GCP storage driver instance
	#
	# return: FireCloudClient object
	def initialize
		self.access_token = FireCloudClient.generate_access_token
		self.api_root = BASE_URL

		# instantiate Google Cloud Storage driver to work with files in workspace buckets
		self.storage = Google::Cloud::Storage.new(
				project: PORTAL_NAMESPACE,
				keyfile: SERVICE_ACCOUNT_KEY,
				timeout: 3600
		)

		# set expiration date of token
		self.expires_at = Time.now + self.access_token['expires_in']
	end

	## TOKEN METHODS

	# generate an access token to use for all requests
	#
	# return: Hash of Google Auth access token
	# (contains access_token (string), token_type (string) and expires_in (integer, in seconds)
	def self.generate_access_token
		json_key = File.open(SERVICE_ACCOUNT_KEY)
		creds = Google::Auth::ServiceAccountCredentials.make_creds(json_key_io: json_key, scope: GOOGLE_SCOPES)
		token = creds.fetch_access_token!
		token
	end

	# refresh access_token when expired and stores back in FireCloudClient instance
	#
	# return: nil
	def refresh_access_token
		new_token = FireCloudClient.generate_access_token
		new_expiry = Time.now + new_token['expires_in']
		self.access_token = new_token
		self.expires_at = new_expiry
	end

	# check if an access_token is expired
	#
	# return: boolean of token exipiration
	def access_token_expired?
		Time.now >= self.expires_at
	end

	## FIRECLOUD METHODS

	# generic handler to execute http calls, process returned JSON and handle exceptions
	#
	# param: http_method (string, symbol) => valid http method
	# param: path (string) => FireCloud REST API path
	# param: payload (hash) => HTTP POST/PATCH/PUT body for creates/updates, defaults to nil
	#
	# return: object depends on response code
	def process_firecloud_request(http_method, path, payload=nil)
		# check for token expiry first before executing
		if self.access_token_expired?
			Rails.logger.info "#{Time.now}: Token expired, refreshing access token"
			self.refresh_access_token
		end
		# set default headers
		headers = {
				'Authorization' => "Bearer #{self.access_token['access_token']}",
				'Content-Type' => 'application/json',
				'Accept' => 'application/json'
		}
		# initialize counter to prevent endless feedback loop
		@retry_count.nil? ? @retry_count = 0 : nil
		if @retry_count < MAX_RETRY_COUNT
			begin
				@retry_count += 1
				@obj = RestClient::Request.execute(method: http_method, url: path, payload: payload, headers: headers)
				# handle response codes as necessary
				if self.ok?(@obj.code) && !@obj.body.blank?
					@retry_count = 0
					return JSON.parse(@obj.body)
				elsif self.ok?(@obj.code) && @obj.body.blank?
					@retry_count = 0
					return true
				else
					Rails.logger.info "#{Time.now}: Unexpected response #{@obj.code}, not sure what to do here..."
					@obj.message
				end
			rescue RestClient::Exception => e
				context = " encountered when requesting '#{path}'"
				log_message = "#{Time.now}: " + e.message + context
				Rails.logger.error log_message
				@error = e.message
				process_firecloud_request(http_method, path, payload)
			end
		else
			@retry_count = 0
			Rails.logger.error "#{Time.now}: Retry count exceeded - #{@error}"
			raise RuntimeError.new("Retry count exceeded - #{@error}")
		end
	end

	# return a list of all workspaces in the portal namespace
	#
	# return: array of JSON objects detailing workspaces
	def workspaces
		path = self.api_root + '/api/workspaces'
		workspaces = process_firecloud_request(:get, path)
		workspaces.keep_if {|ws| ws['workspace']['namespace'] == PORTAL_NAMESPACE}
	end

	# create a workspace, prepending WORKSPACE_NAME_PREFIX as necessary
	#
	# param: workspace_name (string) => name of workspace
	#
	# return: JSON object of workspace instance
	def create_workspace(workspace_name)
		path = self.api_root + '/api/workspaces'
		# construct payload for POST
		payload = {
				namespace: PORTAL_NAMESPACE,
				name: workspace_name,
				attributes: {}
		}.to_json
		process_firecloud_request(:post, path, payload)
	end

	# get the specified workspace
	#
	# param: workspace_name (string) => name of workspace
	#
	# return: JSON object of workspace instance
	def get_workspace(workspace_name)
		path = self.api_root + "/api/workspaces/#{PORTAL_NAMESPACE}/#{workspace_name}"
		process_firecloud_request(:get, path)
	end

	# delete a workspace
	#
	# param: workspace_name (string) => name of workspace
	#
	# return: JSON message of status of workspace deletion
	def delete_workspace(workspace_name)
		path = self.api_root + "/api/workspaces/#{PORTAL_NAMESPACE}/#{workspace_name}"
		process_firecloud_request(:delete, path)
	end

	# get the specified workspace ACL
	#
	# param: workspace_name (string) => name of workspace
	#
	# return: JSON object of workspace ACL instance
	def get_workspace_acl(workspace_name)
		path = self.api_root + "/api/workspaces/#{PORTAL_NAMESPACE}/#{workspace_name}/acl"
		process_firecloud_request(:get, path)
	end

	# update the specified workspace ACL
	# can also be used to remove access by passing 'NO ACCESS' to create_acl
	#
	# param: workspace_name (string) => name of workspace
	# param: acl (JSON) => ACL object (see create_acl)
	#
	# return: JSON response of ACL update
	def update_workspace_acl(workspace_name, acl)
		path = self.api_root + "/api/workspaces/#{PORTAL_NAMESPACE}/#{workspace_name}/acl?inviteUsersNotFound=true"
		process_firecloud_request(:patch, path, acl)
	end

	# helper for creating FireCloud ACL objects
	# will raise a RuntimeError if permission requested does not match allowed values in WORKSPACE_PERMISSONS
	#
	# param: email (string) => email of FireCloud user
	# param: permission (string) => granted permission level
	#
	# return: JSON-encoded ACL object for use in HTTP body
	def create_acl(email, permission)
		if WORKSPACE_PERMISSIONS.include?(permission)
			[
					{
							'email' => email,
							'accessLevel' => permission,
							'canShare' => true
					}
			].to_json
		else
			raise RuntimeError.new("Invalid FireCloud ACL permission setting: #{permission}")
		end
	end

	## GOOGLE CLOUD STORAGE METHODS
	##
	## All methods are convenience wrappers around google-cloud-storage methods
	## see https://googlecloudplatform.github.io/google-cloud-ruby/#/docs/google-cloud-storage/v0.23.2 for more detail

	# generic handler to process
	def execute_gcloud_method(method_name, *params)
		@retries ||= 0
		if @retries < MAX_RETRY_COUNT
			begin
				self.send(method_name, *params)
			rescue => e
				@error = e.message
				Rails.logger.info "#{Time.now}: error calling #{method_name} with #{params.join(', ')}; #{e.message} -- retry ##{@retries}"
				@retries += 1
				execute_gcloud_method(method_name, *params)
			end
		else
			Rails.logger.info "#{Time.now}: Retry count exceeded: #{@error}"
			raise RuntimeError.new "#{@error}"
		end
	end

	# retrieve a workspace's GCP bucket
	#
	# param: workspace_name (string) => name of workspace
	#
	# return: GoogleCloudStorage Bucket object
	def get_workspace_bucket(workspace_name)
		workspace = self.get_workspace(workspace_name)
		bucket_name = workspace['workspace']['bucketName']
		self.storage.bucket bucket_name
	end

	# retrieve all files in a GCP bucket of a workspace
	#
	# param: workspace_name (string) => name of workspace
	# param: opts (hash) => hash of optional parameters, see
	# https://googlecloudplatform.github.io/google-cloud-ruby/#/docs/google-cloud-storage/v0.23.2/google/cloud/storage/bucket?method=files-instance
	#
	# return: array of GoogleCloudStorage File objects
	def get_workspace_files(workspace_name, opts={})
		bucket = self.execute_gcloud_method(:get_workspace_bucket, workspace_name)
		bucket.files(opts)
	end

	# retrieve single study_file in a GCP bucket of a workspace
	#
	# param: workspace_name (string) => name of workspace
	# param: filename (string) => name of file
	#
	# return: Google::Cloud::Storage::File::List
	def get_workspace_file(workspace_name, filename)
		bucket = self.execute_gcloud_method(:get_workspace_bucket, workspace_name)
		bucket.files.select {|file| file.name == filename}.first
	end

	# add a study_file to a workspace bucket
	#
	# param: workspace_name (string) => name of workspace
	# param: filepath (string) => path to file
	# param: filename (string) => name of file
	#
	# return: Google::Cloud::Storage::File
	def create_workspace_file(workspace_name, filepath, filename)
		bucket = self.execute_gcloud_method(:get_workspace_bucket, workspace_name)
		bucket.create_file filepath, filename
	end

	# delete a study_file to a workspace bucket
	#
	# param: workspace_name (string) => name of workspace
	# param: filename (string) => name of file
	#
	# return: true on file deletion
	def delete_workspace_file(workspace_name, filename)
		file = self.execute_gcloud_method(:get_workspace_file, workspace_name, filename)
		file.delete
	end

	# generate a signed url to download a file that isn't public (set at study level)
	#
	# param: workspace_name (string) => name of workspace
	# param: filename (string) => name of file
	# param: opts (hash) => extra options for signed_url, see
	# https://googlecloudplatform.github.io/google-cloud-ruby/#/docs/google-cloud-storage/v0.23.2/google/cloud/storage/file?method=signed_url-instance
	#
	# return: signed URL (string)
	def generate_signed_url(workspace_name, filename, opts={})
		file = self.execute_gcloud_method(:get_workspace_file, workspace_name, filename)
		file.signed_url(opts)
	end

	# check if OK response code was found
	#
	# param: code (integer) => integer HTTP response code
	#
	# return: boolean of whether or not response is a known 'OK' response
	def ok?(code)
		[200, 201, 202, 206].include?(code)
	end
end