class FireCloudClient < Struct.new(:user, :project, :access_token, :api_root, :storage, :expires_at)

	###
  #
  # FireCloudClient: Class that wraps API calls to both FireCloud and Google Cloud Storage to manage the CRUDing of both
  # FireCloud workspaces and files inside the associated GCP storage buckets
	#
	# Uses the gems googleauth (for generating access tokens), google-cloud-storage (for bucket/file access),
	# and rest-client (for HTTP calls)
  #
  ###

	## CONSTANTS
	# base url for all API calls
	BASE_URL = 'https://api.firecloud.org'
	# default auth scopes
	GOOGLE_SCOPES = %w(https://www.googleapis.com/auth/userinfo.profile https://www.googleapis.com/auth/userinfo.email)
	# constant used for retry loops in process_request
	MAX_RETRY_COUNT = 3
	# default namespace used for all FireCloud project workspaces owned by the 'portal'
	PORTAL_NAMESPACE = 'single-cell-portal'
	# location of Google service account JSON (must be absolute path to file)
	SERVICE_ACCOUNT_KEY = File.absolute_path(ENV['SERVICE_ACCOUNT_KEY'])
	# Permission values allowed for ACLs
	WORKSPACE_PERMISSIONS = ['OWNER', 'READER', 'WRITER', 'NO ACCESS']

	## CONSTRUCTOR
	#
	# initialize is called after instantiating with FireCloudClient.new
	# will set the access token, FireCloud api url root and GCP storage driver instance
	#
	# return: FireCloudClient object
	def initialize(user=nil, project=nil)
		# when initializing without a user, default to base configuration
		if user.nil?
			self.access_token = FireCloudClient.generate_access_token
			self.project = PORTAL_NAMESPACE

			# instantiate Google Cloud Storage driver to work with files in workspace buckets
			self.storage = Google::Cloud::Storage.new(
					project: PORTAL_NAMESPACE,
					keyfile: SERVICE_ACCOUNT_KEY,
					timeout: 3600
			)
			# set expiration date of token
			self.expires_at = Time.now + self.access_token['expires_in']
		else
			self.user = user
			self.project = project
			# when initializing with a user, pull access token from user object and set desired project
			self.access_token = user.valid_access_token
			self.expires_at = self.access_token['expires_at']

			# use user-defined project instead of portal default
			self.storage = Google::Cloud::Storage.new(
					project: project,
					keyfile: SERVICE_ACCOUNT_KEY,
					timeout: 3600
			)
		end

		# set FireCloud API base url
		self.api_root = BASE_URL
	end

	##
	## TOKEN METHODS
	##

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
	# return: timestamp of new access token expiration
	def refresh_access_token
		if self.user.nil?
			new_token = FireCloudClient.generate_access_token
			new_expiry = Time.now + new_token['expires_in']
			self.access_token = new_token
			self.expires_at = new_expiry
		else
			new_token = self.user.generate_access_token
			self.access_token = new_token
			self.expires_at = new_token['expires_at']
		end
		self.expires_at
	end

	# check if an access_token is expired
	#
	# return: boolean of token expiration
	def access_token_expired?
		Time.now >= self.expires_at
	end

	##
	## STORAGE INSTANCE METHODS
	##

  # get instance information about the storage driver
  #
  # return: JSON object of storage driver instance attributes
  def storage_attributes
		JSON.parse self.storage.to_json
	end

  # renew the storage driver
  # default project is value of PORTAL_NAMESPACE
  #
  # return: new instance of storage driver
  def refresh_storage_driver(project_name=PORTAL_NAMESPACE)
		new_storage = Google::Cloud::Storage.new(
				project: project_name,
				keyfile: SERVICE_ACCOUNT_KEY,
				timeout: 3600
		)
		self.storage = new_storage
	end

  # get storage driver access token
  #
  # return: access token (string)
  def storage_access_token
		attr = self.storage_attributes
		begin
			attr['service']['credentials']['client']['access_token']
		rescue NoMethodError => e
			Rails.logger.error "#{Time.now}: cannot retrieve GCS storage access token: #{e.message}"
			nil
		end
	end

  # get storage driver issue timestamp
  #
  # return: issue timestamp (DateTime)
  def storage_issued_at
		attr = self.storage_attributes
		begin
			DateTime.parse attr['service']['credentials']['client']['issued_at']
		rescue NoMethodError => e
			Rails.logger.error "#{Time.now}: cannot retrieve GCS storage issued_at timestamp: #{e.message}"
			nil
		end
	end

	######
	##
	## FIRECLOUD METHODS
	##
	######

	# generic handler to execute http calls, process returned JSON and handle exceptions
	#
	# param: http_method (string, symbol) => valid http method
	# param: path (string) => FireCloud REST API path
	# param: payload (hash) => HTTP POST/PATCH/PUT body for creates/updates, defaults to nil
	#
	# return: object depends on response code
	def process_firecloud_request(http_method, path, payload=nil, file_upload=false)
		# check for token expiry first before executing
		if self.access_token_expired?
			Rails.logger.info "#{Time.now}: Token expired, refreshing access token"
			self.refresh_access_token
		end
		# set default headers
		headers = {
				'Authorization' => "Bearer #{self.access_token['access_token']}"
		}
		# if not uploading a file, set the content_type to application/json
		if !file_upload
			headers.merge!({'Content-Type' => 'application/json'})
		end

		# initialize counter to prevent endless feedback loop
		@retry_count.nil? ? @retry_count = 0 : nil
		if @retry_count < MAX_RETRY_COUNT
			begin
				@retry_count += 1
				@obj = RestClient::Request.execute(method: http_method, url: path, payload: payload, headers: headers)
				# handle response codes as necessary
				if self.ok?(@obj.code) && !@obj.body.blank?
					@retry_count = 0
					begin
						return JSON.parse(@obj.body)
					rescue JSON::ParserError => e
						return @obj.body
					end
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
			raise RuntimeError.new(@error)
		end
	end

	##
	## API STATUS
	##

	# determine if FireCloud api is currently up/available
	#
	# return: boolean indication of FireCloud current status
	def api_available?
		path = self.api_root + '/health'
		begin
			process_firecloud_request(:get, path)
			true
		rescue RuntimeError => e
			false
		rescue Errno::ECONNREFUSED => e
			false
		end
  end

  # get more detailed status information about FireCloud api
  # this method doesn't use process_firecloud_request as we want to preserve error states rather than catch and suppress them
  #
  # return: JSON object with health status information for various FireCloud services
  def api_status
    path = self.api_root + '/status'
    # make sure access token is still valid
    self.access_token_expired? ? self.refresh_access_token : nil
    headers = {
        'Authorization' => "Bearer #{self.access_token['access_token']}",
        'Content-Type' => 'application/json',
        'Accept' => 'application/json'
    }
    begin
      response = RestClient::Request.execute(method: :get, url: path, headers: headers)
      JSON.parse(response.body)
    rescue RestClient::ExceptionWithResponse => e
      Rails.logger.error "#{Time.now}: FireCloud status error: #{e.message}"
      e.response
    end
  end

	##
	## WORKSPACE METHODS
	##

	# return a list of all workspaces in the portal namespace
	#
	# return: array of JSON objects detailing workspaces
	def workspaces
		path = self.api_root + '/api/workspaces'
		workspaces = process_firecloud_request(:get, path)
		workspaces.keep_if {|ws| ws['workspace']['namespace'] == self.project}
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
				namespace: self.project,
				name: workspace_name,
				attributes: {},
				authorizationDomain: []
		}.to_json
		process_firecloud_request(:post, path, payload)
	end

	# get the specified workspace
	#
	# param: workspace_name (string) => name of workspace
	#
	# return: JSON object of workspace instance
	def get_workspace(workspace_name)
		path = self.api_root + "/api/workspaces/#{self.project}/#{workspace_name}"
		process_firecloud_request(:get, path)
	end

	# delete a workspace
	#
	# param: workspace_name (string) => name of workspace
	#
	# return: JSON message of status of workspace deletion
	def delete_workspace(workspace_name)
		path = self.api_root + "/api/workspaces/#{self.project}/#{workspace_name}"
		process_firecloud_request(:delete, path)
	end

	# get the specified workspace ACL
	#
	# param: workspace_name (string) => name of workspace
	#
	# return: JSON object of workspace ACL instance
	def get_workspace_acl(workspace_name)
		path = self.api_root + "/api/workspaces/#{self.project}/#{workspace_name}/acl"
		process_firecloud_request(:get, path)
	end

	# update the specified workspace ACL
	# can also be used to remove access by passing 'NO ACCESS' to create_acl
	#
	# param: workspace_name (string) => name of workspace
	# param: acl (JSON) => ACL object (see create_workspace_acl)
	#
	# return: JSON response of ACL update
	def update_workspace_acl(workspace_name, acl)
		path = self.api_root + "/api/workspaces/#{self.project}/#{workspace_name}/acl?inviteUsersNotFound=true"
		process_firecloud_request(:patch, path, acl)
	end

	# helper for creating FireCloud ACL objects
	# will raise a RuntimeError if permission requested does not match allowed values in WORKSPACE_PERMISSONS
	#
	# param: email (string) => email of FireCloud user
	# param: permission (string) => granted permission level
	#
	# return: JSON-encoded ACL object for use in HTTP body
	def create_workspace_acl(email, permission)
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

  ##
  ## WORKFLOW SUBMISSION METHODS
	##

  # get list of available FireCloud methods
  #
  # param: opts (hash) => hash of query parameter key/value pairs, see https://api.firecloud.org/#!/Method_Repository/listMethodRepositoryMethods for complete list
  #
  # return: array of methods
  def get_methods(opts={})
		query_params = self.merge_query_options(opts)
		path = self.api_root + "/api/methods#{query_params}"
		process_firecloud_request(:get, path)
	end

	# get a FireCloud method object
	#
	# param: namespace (string) => namespace of method
	# param: name (string) => name of method
	# param: snapshot_id (integer) => snapshot ID of method
	# param: only_payload (boolean) => boolean of whether or not to return only the payload object
  #
	# return: array of methods
	def get_method(namespace, method_name, snapshot_id, only_payload=false)
		path = self.api_root + "/api/methods/#{namespace}/#{method_name}/#{snapshot_id}?onlyPayload=#{only_payload}"
		process_firecloud_request(:get, path)
	end

	# get list of available configurations
	#
	# param: opts (hash) => hash of query parameter key/value pairs, see https://api.firecloud.org/#!/Method_Repository/listMethodRepositoryConfigurations for complete list
	#
	# return: array of configurations
	def get_configurations(opts={})
		query_params = self.merge_query_options(opts)
		path = self.api_root + "/api/configurations#{query_params}"
		process_firecloud_request(:get, path)
	end

	# get a FireCloud method configuration
	#
	# param: namespace (string) => namespace of method
	# param: name (string) => name of method
	# param: snapshot_id (integer) => snapshot ID of method
	#
	# return: configuration object
	def get_configuration(namespace, method_name, snapshot_id)
		path = self.api_root + "/api/configurations/#{namespace}/#{method_name}/#{snapshot_id}"
		process_firecloud_request(:get, path)
	end

  # get submission queue status
  #
  # return: JSON object of current submission queue status
	def get_submission_queue_status
		path = self.api_root + '/api/submissions/queueStatus'
		process_firecloud_request(:get, path)
	end

  # get a list of workspace workflow queue submissions
  #
	# param: workspace_name (string) => name of requested workspace
  #
  # return: array of workflow submissions
  def get_workspace_submissions(workspace_name)
		path = self.api_root + "/api/workspaces/#{self.project}/#{workspace_name}/submissions"
		process_firecloud_request(:get, path)
	end

	# create a workflow queue submissions
	#
	# param: workspace_name (string) => name of requested workspace
	# param: submission (hash) => hash of submission parameters
	#
	# return: array of workflow submissions
	def create_workspace_submission(workspace_name, submission)
		path = self.api_root + "/api/workspaces/#{self.project}/#{workspace_name}/submissions"
		process_firecloud_request(:post, path, submission.to_json)
	end

	# monitor a workflow queue submission status
	#
	# param: workspace_name (string) => name of requested workspace
	# param: submission_id (integer) => ID of workflow submission
	#
	# return: array of workflow submissions
	def monitor_workspace_submission(workspace_name, submission_id)
		path = self.api_root + "/api/workspaces/#{self.project}/#{workspace_name}/submissions/#{submission_id}"
		process_firecloud_request(:get, path)
	end

	# abort a workflow queue submission
	#
	# param: workspace_name (string) => name of requested workspace
	# param: submission_id (integer) => ID of workflow submission
	#
	# return: array of workflow submissions
	def abort_workspace_submission(workspace_name, submission_id)
		path = self.api_root + "/api/workspaces/#{self.project}/#{workspace_name}/submissions/#{submission_id}"
		process_firecloud_request(:delete, path)
	end
	##
	## METADATA ENTITY METHODS
	##

	# list workspace metadata entities with type and attribute information
	#
	# param: workspace_name (string) => name of requested workspace
	#
	# return: array of workspace metadata entities with type and attribute information
	def get_workspace_entities(workspace_name)
		path = self.api_root + "/api/workspaces/#{self.project}/#{workspace_name}/entities_with_type"
		process_firecloud_request(:get, path)
	end

	# list workspace metadata entity types
	#
	# param: workspace_name (string) => name of requested workspace
	#
	# return: array of workspace metadata entities
	def get_workspace_entity_types(workspace_name)
		path = self.api_root + "/api/workspaces/#{self.project}/#{workspace_name}/entities"
		process_firecloud_request(:get, path)
	end

	# get a list workspace metadata entities of requested type
	#
	# param: workspace_name (string) => name of requested workspace
	# param: entity_type (string) => type of requested entity
	#
	# return: array of workspace metadata entities with type and attribute information
	def get_workspace_entities_by_type(workspace_name, entity_type)
		path = self.api_root + "/api/workspaces/#{self.project}/#{workspace_name}/entities/#{entity_type}"
		process_firecloud_request(:get, path)
	end

	# get an individual workspace metadata entity
	#
	# param: workspace_name (string) => name of requested workspace
	# param: entity_type (string) => type of requested entity
	# param: entity_name (string) => name of requested entity
	#
	# return: array of workspace metadata entities with type and attribute information
	def get_workspace_entity(workspace_name, entity_type, entity_name)
		path = self.api_root + "/api/workspaces/#{self.project}/#{workspace_name}/entities/#{entity_type}/#{entity_name}"
		process_firecloud_request(:get, path)
	end

	# update an individual workspace metadata entity
	#
	# param: workspace_name (string) => name of requested workspace
	# param: entity_type (string) => type of requested entity
	# param: entity_name (string) => name of requested entity
	# param: operation_type (string) => type of operation requested (add/update)
	# param: attribute_name (string) => name of attribute being changed
  # param: attribute_value (string) => value of attribute being changed
	#
	# return: array of workspace metadata entities with type and attribute information
	def update_workspace_entity(workspace_name, entity_type, entity_name, operation_type, attribute_name, attribute_value)
		update = {
				op: operation_type,
				attributeName: attribute_name,
				addUpdateAttribute: attribute_value
		}.to_json
		path = self.api_root + "/api/workspaces/#{self.project}/#{workspace_name}/entities/#{entity_type}/#{entity_name}"
		process_firecloud_request(:patch, path, update)
	end

	# get a tsv file of requested workspace metadata entities of requested type
	#
	# param: workspace_name (string) => name of requested workspace
	# param: entity_type (string) => type of requested entity
  # param: entity_names (string) => list of requested entities to include in file (provide each as a separate parameter)
	#
	# return: array of workspace metadata entities with type and attribute information
	def get_workspace_entities_as_tsv(workspace_name, entity_type, *entity_names)
		entity_list = entity_names.join(',')
		path = self.api_root + "/api/workspaces/#{self.project}/#{workspace_name}/entities/#{entity_type}#{entity_list.blank? ? nil : '?attributeNames=' + entity_list}"
		process_firecloud_request(:get, path)
	end

	# get a tsv file of requested workspace metadata entities of requested type
	#
	# param: workspace_name (string) => name of requested workspace
	# param: entities_file (file) => valid TSV import file of metadata entities (must be an open File handler)
	#
	# return: array of workspace metadata entities with type and attribute information
	def import_workspace_entities_file(workspace_name, entities_file)
		path = self.api_root + "/api/workspaces/#{self.project}/#{workspace_name}/importEntities"
		entities_upload = {
				entities: entities_file
		}
		process_firecloud_request(:post, path, entities_upload, true)
	end

	# bulk delete workspace metadata entities
	#
	# param: workspace_name (string) => name of requested workspace
  # param: workspace_entities (array of objects) => array of hashes mapping to workspace metadata entities
	#
	# return: array of workspace metadata entities
	def delete_workspace_entities(workspace_name, workspace_entities)
		# validate entities first before making delete call
		valid_workspace_entities = []
		workspace_entities.each do |entity|
			if entity.keys.sort.map(&:to_s) == %w(entityName entityType) && entity.values.size == 2
				valid_workspace_entities << entity
			end
		end
		path = self.api_root + "/api/workspaces/#{self.project}/#{workspace_name}/entities/delete"
		process_firecloud_request(:post, path,  valid_workspace_entities.to_json)
	end

	#######
	##
	## GOOGLE CLOUD STORAGE METHODS
	##
	## All methods are convenience wrappers around google-cloud-storage methods
	## see https://googlecloudplatform.github.io/google-cloud-ruby/#/docs/google-cloud-storage/v0.23.2 for more detail
	##
	#######

	# generic handler to process GCS method with retries and error handling
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
	# return: Google::Cloud::Storage::File::List
	def get_workspace_files(workspace_name, opts={})
		bucket = self.get_workspace_bucket(workspace_name)
		bucket.files(opts)
	end

	# retrieve single study_file in a GCP bucket of a workspace
	#
	# param: workspace_name (string) => name of workspace
	# param: filename (string) => name of file
	#
	# return: Google::Cloud::Storage::File
	def get_workspace_file(workspace_name, filename)
		bucket = self.get_workspace_bucket(workspace_name)
		bucket.file filename
	end

	# add a study_file to a workspace bucket
	#
	# param: workspace_name (string) => name of workspace
	# param: filepath (string) => path to file
	# param: filename (string) => name of file
	# param: opts (hash) => extra options for create_file, see
	# https://googlecloudplatform.github.io/google-cloud-ruby/#/docs/google-cloud-storage/v0.23.2/google/cloud/storage/bucket?method=create_file-instance
	#
	# return: Google::Cloud::Storage::File
	def create_workspace_file(workspace_name, filepath, filename, opts={})
		bucket = self.get_workspace_bucket(workspace_name)
		bucket.create_file filepath, filename, opts
	end

	# delete a study_file to a workspace bucket
	#
	# param: workspace_name (string) => name of workspace
	# param: filename (string) => name of file
	#
	# return: true on file deletion
	def delete_workspace_file(workspace_name, filename)
		file = self.get_workspace_file(workspace_name, filename)
		begin
			file.delete
		rescue => e
			logger.info("#{Time.now}: failed to delete workspace file #{filename} with error #{e.message}")
		end
	end

	# retrieve single file in a GCP bucket of a workspace and download locally to portal (likely for parsing)
	#
	# param: workspace_name (string) => name of workspace
	# param: filename (string) => name of file
	# param: destination (string) => destination path for downloaded file
	#
	# return: File object
	def download_workspace_file(workspace_name, filename, destination)
		file = self.get_workspace_file(workspace_name, filename)
		# create a valid path by combining destination directory and filename, making sure no double / exist
		end_path = [destination, filename].join('/').gsub(/\/\//, '/')
		file.download end_path
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
		file = self.get_workspace_file(workspace_name, filename)
		file.signed_url(opts)
	end

	# retrieve all directories in a GCP bucket of a workspace
	# this is achieved by looking at filenames containing '/' and keeping the preceding token
	# only first-level directories are returned
	#
	# param: workspace_name (string) => name of workspace
	# param: opts (hash) => hash of optional parameters, see
	# https://googlecloudplatform.github.io/google-cloud-ruby/#/docs/google-cloud-storage/v0.23.2/google/cloud/storage/bucket?method=files-instance
	#
	# return: array of Google::Cloud::Storage::File objects mapping to directories
	def get_workspace_directories(workspace_name, opts={})
		files = self.get_workspace_files(workspace_name, opts)
		directories = []
		files.each do |file|
			if file.name.include?('/')
				directories << file.name.split('/').first
			end
		end
		# make sure we've looked at all files
		while files.next?
			files = files.next
			files.each do |file|
				if file.name.include?('/')
					directories << file.name.split('/').first
				end
			end
		end
		directories.uniq
	end

	# retrieve all files in a GCP directory
	#
	# param: workspace_name (string) => name of workspace
	# param: directory (string) => name of directory in bucket
	# param: opts (hash) => hash of optional parameters, see
	# https://googlecloudplatform.github.io/google-cloud-ruby/#/docs/google-cloud-storage/v0.23.2/google/cloud/storage/bucket?method=files-instance
	#
	# return: Google::Cloud::Storage::File::List
	def get_workspace_directory_files(workspace_name, directory, opts={})
		# makes sure directory ends with '/', otherwise append to prevent spurious matches
		directory += '/' unless directory.last == '/'
		opts.merge!(prefix: directory)
		self.get_workspace_files(workspace_name, opts)
	end

	# retrieve number of files in a GCP directory
	#
	# param: workspace_name (string) => name of workspace
	# param: directory (string) => name of directory in bucket
	# param: opts (hash) => hash of optional parameters, see
	# https://googlecloudplatform.github.io/google-cloud-ruby/#/docs/google-cloud-storage/v0.23.2/google/cloud/storage/bucket?method=files-instance
	#
	# return: integer count of files in directory (ignoring 0 size objects which may be folders)
	def get_workspace_directory_size(workspace_name, directory, opts={})
		# makes sure directory ends with '/', otherwise append to prevent spurious matches
		directory += '/' unless directory.last == '/'
		opts.merge!(prefix: directory)
		files = self.get_workspace_directory_files(workspace_name, directory, opts)
		count = 0
		files.each do |file|
			count += 1 if file.size != 0
		end
		# make sure we've counted all files
		while files.next?
			files = files.next
			files.each do |file|
				count += 1 if file.size != 0
			end
		end
		count
	end

  #######
  ##
  ## UTILITY METHODS
	##
  #######

	# check if OK response code was found
	#
	# param: code (integer) => integer HTTP response code
	#
	# return: boolean of whether or not response is a known 'OK' response
	def ok?(code)
		[200, 201, 202, 204, 206].include?(code)
	end

  # merge hash of options into single URL query string
  #
	# param: opts (hash) => hash of query parameter key/value pairs
  #
  # return: string of concatenated query params
  def merge_query_options(opts)
		# return nil if opts is empty, else concat
		opts.blank? ? nil : '?' + opts.to_a.map {|k,v| "#{k}=#{v}"}.join("&")
	end

  # validate the structure of a workspace entity object ()
end