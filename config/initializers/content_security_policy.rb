# Be sure to restart your server when you modify this file.

# Define an application-wide content security policy
# For further information see the following documentation
# https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Content-Security-Policy

Rails.application.config.content_security_policy do |policy|
  policy.default_src :self, :https, :unsafe_inline
  policy.font_src    :self
  policy.img_src     :self, :data, 'https://www.google-analytics.com'
  policy.object_src  :none
  policy.script_src  "https://#{ENV['PROD_HOSTNAME']}", :blob, :strict_dynamic, :unsafe_eval, 'https://cdn.plot.ly',
                     'https://cdn.datatables.net', 'https://www.google-analytics.com', 'https://cdnjs.cloudflare.com',
                     'https://maxcdn.bootstrapcdn.com', 'https://use.fontawesome.com'
  policy.style_src   :self, :https, 'https://maxcdn.bootstrapcdn.com', :unsafe_inline

#   # Specify URI for violation reports
#   # policy.report_uri "/csp-violation-report-endpoint"
end

# If you are using UJS then enable automatic nonce generation
Rails.application.config.content_security_policy_nonce_generator = -> request { SecureRandom.base64(16) }

# Report CSP violations to a specified URI
# For further information see the following documentation:
# https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Content-Security-Policy-Report-Only
# Rails.application.config.content_security_policy_report_only = true