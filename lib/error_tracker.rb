module ErrorTracker

  # capture and report an exception to Sentry via Raven, setting user context & params as needed
  def self.capture_raven_exception(exception, user, extra_context={})
    user_context = {identifer: nil}
    if user.is_a?(User)
      user_context[:identifer] = user.id.to_s
    elsif user.is_a?(String)
      user_context[:identifer] = user
    end
    Raven.capture_exception(exception, user: user_context, extra: extra_context)
  end
end