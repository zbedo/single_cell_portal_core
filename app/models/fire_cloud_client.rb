class FireCloudClient < Struct.new(:access_token, :api_root, :storage)

	## CONSTANTS
	# base url for all API calls
	BASE_URL = 'https://api.firecloud.org'
	# location of Google service account JSON (must be absolute path to file)
	SERVICE_ACCOUNT_KEY ||= ENV['SERVICE_ACCOUNT_KEY'] || File.absolute_path(Rails.root.join('config', 'broad-singlecellportal-d5dad9c8d7db.json'))
	# default auth scopes
	GOOGLE_SCOPES = %w(https://www.googleapis.com/auth/userinfo.profile https://www.googleapis.com/auth/userinfo.email)
	# namespace used for all FireCloud project workspaces
	PORTAL_NAMESPACE = 'single-cell-portal'
	# Permission values allowed for ACLs
	WORKSPACE_PERMISSIONS = ['OWNER', 'READER', 'WRITER', 'NO ACCESS']
	# constant used for retry loops in process_request
	MAX_RETRY_COUNT = 3
	# prefix for workspaces, defaults to blank in production
	WORKSPACE_NAME_PREFIX = Rails.env != 'production' ? Rails.env + '-' : ''

	## CONTRUCTORS
	def initialize
		self.access_token = FireCloudClient.get_access_token
		self.api_root = BASE_URL

		# instantiate Google Cloud Storage driver to work with files in workspace buckets
		self.storage = Google::Cloud::Storage.new(
				project: PORTAL_NAMESPACE,
				keyfile: SERVICE_ACCOUNT_KEY
		)
	end

	# retrieve an access token to use for all requests
	def self.get_access_token
		json_key = File.open(SERVICE_ACCOUNT_KEY)
		creds = Google::Auth::ServiceAccountCredentials.make_creds(json_key_io: json_key, scope: GOOGLE_SCOPES)
		token = creds.fetch_access_token
		token
	end

	# generic handler to execute http calls, process returned JSON and handle exceptions
	# param: http_method (string, symbol) => valid http method
	# param: path (string) => FireCloud REST API path
	# param: payload (hash) => HTTP POST/PATCH/PUT body for creates/updates, defaults to nil
	# path is constructed in parent object and retrieved from FireCloud
	# object is then returned for further processing if necessary
	def process_request(http_method, path, payload=nil)
		# set default headers
		headers = {
				'Authorization' => "Bearer #{self.access_token['access_token']}",
				'Content-Type' => 'application/json',
				'Accept' => 'application/json'
		}
		# initialize counter to prevent endless feedback loop
		@retry_count.nil? ? @retry_count = 0 : nil
		if @retry_count < MAX_RETRY_COUNT
			@retry_count += 1
			begin
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
				@retry_count = 0
				context = " encountered when requesting '#{path}'"
				Rails.logger.error "#{Time.now}: " + e.message + context
				false
			end
		else
			@retry_count = 0
			Rails.logger.error "#{Time.now}: Retry count exceeded - #{@error}"
			raise RuntimeError.new("Retry count exceeded - #{@error}")
		end
	end

	# return a list of all workspaces in the portal namespace
	def workspaces
		path = self.api_root + '/api/workspaces'
		workspaces = process_request(:get, path)
		workspaces.keep_if {|ws| ws['workspace']['namespace'] == PORTAL_NAMESPACE}
	end

	# get the specified workspace
	#
	# param: name (string) => name of workspace
	def get_workspace(name)
		path = self.api_root + "/api/workspaces/#{PORTAL_NAMESPACE}/#{WORKSPACE_NAME_PREFIX}#{name}"
		process_request(:get, path)
	end

	# create a workspace, prepending WORKSPACE_NAME_PREFIX as necessary
	#
	# param: name (string) => name of workspace
	def create_workspace(name)
		path = self.api_root + '/api/workspaces'
		# construct payload for POST
		payload = {
				namespace: PORTAL_NAMESPACE,
				name: "#{WORKSPACE_NAME_PREFIX}#{name}",
				attributes: {}
		}.to_json
		process_request(:post, path, payload)
	end

	# delete a workspace
	#
	# param: name (string) => name of workspace
	def delete_workspace(name)
		path = self.api_root + "/api/workspaces/#{PORTAL_NAMESPACE}/#{WORKSPACE_NAME_PREFIX}#{name}"
		process_request(:delete, path)
	end

	# get the specified workspace ACL
	#
	# param: name (string) => name of workspace
	def get_workspace_acl(name)
		path = self.api_root + "/api/workspaces/#{PORTAL_NAMESPACE}/#{WORKSPACE_NAME_PREFIX}#{name}/acl"
		process_request(:get, path)
	end

	# update the specified workspace ACL
	# can also be used to remove access
	#
	# param: name (string) => name of workspace
	# param: act (JSON) => ACL object (see create_acl)
	def update_workspace_acl(name, acl)
		granted_permission = JSON.parse(acl).first['accessLevel']
		if WORKSPACE_PERMISSIONS.include?(granted_permission)
			path = self.api_root + "/api/workspaces/#{PORTAL_NAMESPACE}/#{WORKSPACE_NAME_PREFIX}#{name}/acl"
			process_request(:patch, path, acl)
		else
			Rails.logger.error "#{Time.now}: Invalid ACL permission (#{granted_permission}) specified for workspace #{name}"
			false
		end
	end

	# helper for creating FireCloud ACL objects
	#
	# param: email (string) => email of FireCloud user
	# param: permission (string) => granted permission level
	def create_acl(email, permission)
		[
				{
						'email' => email,
						'accessLevel' => permission,
						'canShare' => true
				}
		].to_json
	end

	# retrieve a workspace's GCP bucket
	#
	# param: name (string) => name of workspace
	def get_workspace_bucket(name)
		workspace = self.get_workspace(name)
		bucket_name = workspace['workspace']['bucketName']
		self.storage.bucket bucket_name
	end

	# retrieve all files in a GCP bucket of a workspace
	#
	# param: name (string) => name of workspace
	def get_workspace_files(name)
		bucket = self.get_workspace_bucket(name)
		bucket.files
	end

	def download_workspace_file(name, filename)
		workspace = self.get_workspace(name)
		bucket_name = workspace['workspace']['bucketName']
		path = self.api_root + "/cookie-authed/download/b/#{bucket_name}/o/#{filename}"
		process_request(:get, path)
	end

	# check if OK response code was found
	def ok?(code)
		[200, 201, 202, 206].include?(code)
	end
end