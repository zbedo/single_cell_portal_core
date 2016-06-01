#! /usr/bin/env ruby

require 'net/smtp'

WEB_DIR = File.expand_path(File.join(File.dirname(__FILE__), '..'))
Dir.chdir(WEB_DIR)

# get command line arguments for environment and number of workers
@env = ARGV[0].nil? ? "production" : ARGV[0]
@num_workers = ARGV[1].nil? ? 4 : ARGV[1]

@from_email = 'no-reply@broadinstitute.org'
@to_email = 'bistline@broadinstitute.org'

# get current delayed_job status messages
dj_status = `bin/delayed_job status #{@env}`

# checks to see if any workers have been killed
@date = Time.now.strftime("%Y-%m-%d %H:%M:%S")
if dj_status.include?("killed") || dj_status.include?("no instances running")
	@log_message =  "#{@date}: One or more delayed_job workers have died.  Restarting daemon.\n"

	# restart delayed job workers and update log message
	system("bin/delayed_job restart #{@env} -n #{@num_workers}")
	new_status = `bin/delayed_job status #{@env}`
	new_time = Time.now.strftime("%Y-%m-%d %H:%M:%S")
	new_status.split("\n").each {|status| @log_message << "#{new_time}: #{status}\n"}

	# send email to admin
	Net::SMTP.start('smtp.sendgrid.net', 587, ENV['SENDGRID_USERNAME'], ENV['SENDGRID_PASSWORD'],:plain) do |smtp|
		smtp.open_message_stream(@from_email, @to_email) do |contents|
			contents.puts "From: #{@from_email}"
			contents.puts "To: #{@to_email}"
			contents.puts "Content-Type: text/html; charset=utf-8"
			contents.puts "Subject: Single Cell DelayedJob workers died as of #{@date}"
			contents.puts ""
			contents.puts "#{@log_message.gsub(/\n/, '<br />')}"
		end
	end
end