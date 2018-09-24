SwaggerUiEngine.configure do |config|
  config.swagger_url = {
      v1: '/single_cell/api/api_docs.json'
  }
  config.doc_expansion = 'full'
  config.model_rendering = 'model'
  config.validator_enabled = false
  config.oauth_client_id = "#{ENV['OAUTH_CLIENT_ID']}"
  config.oauth_client_secret = "#{ENV['OAUTH_CLIENT_SECRET']}"
  config.request_headers = false
end