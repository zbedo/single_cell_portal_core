#! /usr/bin/env ruby

# roll over log files every time app is rebooted

require "fileutils"

APP_ROOT = File.expand_path(File.join(File.dirname(__FILE__), '..'))
Dir.chdir(APP_ROOT)

# set up defaults
@env = "production"

ARGV.each do |arg|
	arg =~ /\-e\=/ ? @env = arg.gsub(/\-e\=/, "") : nil
	arg =~ /\-p\=/ ? @port = arg.gsub(/\-p\=/, "") : nil
end

logs = Dir.entries("log").keep_if {|log| log =~ /#{@env}/}

if logs.include?("#{@env}.4.log")
	File.delete("log/#{@env}.4.log")
end
if logs.include?("#{@env}.3.log")
	File.rename("log/#{@env}.3.log", "log/#{@env}.4.log")
end
if logs.include?("#{@env}.2.log")
	File.rename("log/#{@env}.2.log", "log/#{@env}.3.log")
end
if logs.include?("#{@env}.1.log")
	File.rename("log/#{@env}.1.log", "log/#{@env}.2.log")
end

FileUtils.cp("log/#{@env}.log", "log/#{@env}.1.log")
File.delete("log/#{@env}.log")
