Delayed::Worker.destroy_failed_jobs = true
Delayed::Worker.max_attempts = 1
Delayed::Worker.max_run_time = 24.hours
Delayed::Worker.read_ahead = 10
Delayed::Worker.logger = Logger.new(File.join(Rails.root, 'log', "delayed_job.#{Rails.env}.log"))
Delayed::Worker.default_queue_name = :default

if Rails.env.test? || Rails.env.development? # save a little time in testing/dev
  Delayed::Worker.sleep_delay = 10
end

# Fix intermittent classLoad issues.
# see https://github.com/collectiveidea/delayed_job/issues/779
module Psych::Visitors
  ToRuby.class_eval do
    alias :resolve_class_without_autoload :resolve_class
    def resolve_class klassname
      begin
        require_dependency klassname.underscore
      rescue NameError, LoadError
      end
      resolve_class_without_autoload klassname
    end
  end
end
