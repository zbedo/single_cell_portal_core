# Be sure to restart your server when you modify this file.

# Define an application-wide content security policy
# For further information see the following documentation
# https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Content-Security-Policy

#Rails.application.config.content_security_policy do |policy|

#end

# If you are using UJS then enable automatic nonce generation
# Rails.application.config.content_security_policy_nonce_generator = -> request { SecureRandom.base64(16) }

# Report CSP violations to a specified URI
# For further information see the following documentation:
# https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Content-Security-Policy-Report-Only
# Rails.application.config.content_security_policy_report_only = true

SecureHeaders::Configuration.default do |config|
  config.cookies = {
      secure: true # mark all cookies as "Secure"
  }
  # Add "; preload" and submit the site to hstspreload.org for best protection.
  config.hsts = "max-age=15768000; includeSubdomains; preload"
  config.x_frame_options = "SAMEORIGIN"
  config.x_content_type_options = "nosniff"
  config.x_xss_protection = "1; mode=block"
  config.x_permitted_cross_domain_policies = "none"
  config.referrer_policy = %w(strict-origin-when-cross-origin)
  config.csp = {
      # "meta" values. these will shape the header, but the values are not included in the header.
      preserve_schemes: true, # default: false. Schemes are removed from host sources to save bytes and discourage mixed content.

      # directive values: these values will directly translate into source directives
      default_src: %w('self'),
      block_all_mixed_content: true, # see http://www.w3.org/TR/mixed-content/
      frame_src: %w('self'), # if child-src isn't supported, the value for frame-src will be set.
      font_src: %w('self' data:),
      form_action: %w('self'),
      img_src: %w('self' data: https://www.google-analytics.com),
      manifest_src: %w('self'),
      object_src: %w('none'),
      plugin_types: %w(application/x-shockwave-flash),
      script_src: %w('self' blob: 'unsafe-eval' 'strict-dynamic' https://cdn.plot.ly https://cdn.datatables.net https://www.google-analytics.com
                      https://cdnjs.cloudflare.com https://maxcdn.bootstrapcdn.com https://use.fontawesome.com),
      style_src: %w('self' https://maxcdn.bootstrapcdn.com 'unsafe-inline'),
      upgrade_insecure_requests: true, # see https://www.w3.org/TR/upgrade-insecure-requests/
  }

end