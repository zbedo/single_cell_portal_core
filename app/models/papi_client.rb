##
# PapiClient: a lightweight wrapper around the Google Cloud Genomics API using the google-api-client gem
##

require 'google/apis/genomics_v2alpha1'

class PapiClient < Struct.new(:project, :service_account_credentials, :service)

  SERVICE_ACCOUNT_KEY = !ENV['SERVICE_ACCOUNT_KEY'].blank? ? File.absolute_path(ENV['SERVICE_ACCOUNT_KEY']) : ''
  GOOGLE_SCOPES = %w(https://www.googleapis.com/auth/datastore https://www.googleapis.com/auth/devstorage.read_only)
  COMPUTE_PROJECT = ENV['GOOGLE_CLOUD_PROJECT'].blank? ? '' : ENV['GOOGLE_CLOUD_PROJECT']

  def initialize(project=COMPUTE_PROJECT, service_account_credentials=SERVICE_ACCOUNT_KEY)

    credentials = {
        scope: GOOGLE_SCOPES
    }

    if SERVICE_ACCOUNT_KEY.present?
      credentials.merge!({json_key_io: File.open(service_account)})
    end

    authorizer = Google::Auth::ServiceAccountCredentials.make_creds(credentials)
    genomics_service = Google::Apis::GenomicsV2alpha1::GenomicsService.new
    genomics_service.authorization = authorizer

    self.project = project
    self.service_account_credentials = service_account_credentials
    self.service = genomics_service
  end

  def run_pipeline(*parameters)
    self.service.run_pipeline(parameters)
  end

end
