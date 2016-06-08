class TempFileDownloadCleanup < Struct.new(:threshold)
	DEFAULT_THRESHOLD = 1

	def perform
		@limit = Time.now - threshold.minutes
		TempFileDownload.where(:created_at.lte => @limit).destroy_all
	end

	def max_attempts
		1
	end
end