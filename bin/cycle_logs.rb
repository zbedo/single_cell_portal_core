#! /usr/bin/env ruby

# roll over all log files every time app is rebooted

require "fileutils"

APP_ROOT = File.expand_path(File.join(File.dirname(__FILE__), '..'))
Dir.chdir(APP_ROOT)

all_logs = Dir.entries("log").keep_if {|l| !l.start_with?('.')}

# increment each old log by 1
4.downto(1) do |i|
  if i == 4
    all_logs.select {|l| l =~ /#{i}/}.each do |log|
      File.exists?("log/#{log}") ? File.delete("log/#{log}") : next
    end
  else
    all_logs.select {|l| l =~ /#{i}/}.each do |log|
      log_parts = log.split('.')
      # handling of delayed_job.log is different that delayed_job.[RAILS_ENV].log
      if log_parts.first == 'delayed_job' && log_parts.size == 4
        basename = log_parts[0..1].join('.')
      else
        basename = log_parts.first
      end
      File.exists?("log/#{basename}.#{i}.log") ? File.rename("log/#{basename}.#{i}.log", "log/#{basename}.#{i + 1}.log") : next
    end
  end
end

# find all logs that haven't been rolled over yet and rename
all_logs.select {|l| l.split('.').last == 'log'}.each do |log|
  log_parts = log.split('.')
  if log_parts.first == 'delayed_job' && log_parts.size == 4
    basename = log_parts[0..1].join('.')
  else
    basename = log_parts.first
  end
  if File.exists?("log/#{basename}.log")
    FileUtils.cp("log/#{basename}.log", "log/#{basename}.1.log")
    File.delete("log/#{basename}.log")
  end
end

# blow away any nginx access & error logs
if Dir.exists?('log/nginx')
  Dir.chdir('log/nginx')
  nginx_logs = Dir.entries(".").keep_if {|l| !l.start_with?('.')}
  nginx_logs.each do |log|
    File.delete log
  end
end
