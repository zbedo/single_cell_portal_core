class MarkerFileParseJob < Struct.new(:study, :precomputed_file, :precomputed_name, :user)

	def perform
		study.make_precomputed_scores(precomputed_file, precomputed_name, user)
	end

	def failure(job, user)
		SingleCellMailer.deliver_notify_user_parse_fail(user.email, job.last_error)
	end

	def error(job, exception, user)
		SingleCellMailer.deliver_notify_user_parse_fail(user.email, exception.message)
	end

	def max_attempts
		1
	end
end