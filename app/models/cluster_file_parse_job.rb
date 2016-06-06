class ClusterFileParseJob < Struct.new(:study, :assignment_file, :cluster_file, :cluster_type, :user)

	def perform
		study.make_cluster_points(assignment_file, cluster_file, cluster_type, user)
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