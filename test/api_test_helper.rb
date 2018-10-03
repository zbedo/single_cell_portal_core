ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
require 'rails/test_help'

module Requests
  module JsonHelpers
    # parse a response body as JSON
    def json
      JSON.parse(@response.body)
    end
  end

  module HttpHelpers
    # execute an HTTP call of the specified method to a given path (with optional payload), setting accept & content_type
    # to :json and prepending the authorization bearer token to the headers
    def execute_http_request(method, path, request_payload={})
      send(method.to_sym, path, params: request_payload, as: :json, headers: {authorization: "Bearer #{@user.api_access_token}"})
    end
  end
end