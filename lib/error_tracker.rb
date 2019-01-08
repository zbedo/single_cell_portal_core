module ErrorTracker

  # capture and report an exception to Sentry via Raven, setting user context & params as needed
  def self.report_exception(exception, user, extra_context={})
    # only report to Sentry if configured and not in test environment
    if Rails.env == 'test' || ENV['SENTRY_DSN'].nil?
      Rails.logger.error "Suppressing error reporting to Sentry: #{e.class.name}:#{e.message}"
    else
      Raven.capture_exception(exception, user: {identifer: extract_user_identifier(user)}, extra: extra_context)
    end
  end

  private

  def extract_user_identifier(user)
    if user.is_a?(User)
      user.id.to_s
    else
      user
    end
  end
end