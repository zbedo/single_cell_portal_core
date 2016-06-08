class ExpressionFileParseJob < Struct.new(:study, :expression_file, :user)

	def perform
		study.make_expression_scores(expression_file, user)
	end

	def failure(job)
		SingleCellMailer.deliver_notify_user_parse_fail(user.email, job.last_error)
	end

	def error(job, exception)
		SingleCellMailer.deliver_notify_user_parse_fail(user.email, exception.message)
	end

	def max_attempts
		1
	end
end