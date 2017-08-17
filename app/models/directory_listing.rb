class DirectoryListing
	include Mongoid::Document
	include Mongoid::Timestamps
	include Rails.application.routes.url_helpers # for accessing download_file_path and download_private_file_path

	belongs_to :study

	field :name, type: String
	field :description, type: String
	field :files, type: Array
	field :sync_status, type: Boolean, default: false

	validates_uniqueness_of :name, scope: :study_id

	index({ name: 1, study_id: 1 }, { unique: true })

	# check if a directory_listing has a file
	def has_file?(filename)
		!self.files.detect(filename).nil?
	end

	# helper to generate correct urls for downloading fastq files
	def download_path(file)
		if self.study.public?
			download_file_path(self.study.url_safe_name, file)
		else
			download_private_file_path(self.study.url_safe_name, file)
		end
	end

	# helper to render name appropriately for use in download modals
	def download_display_name
		if self.name == '/'
			self.name
		else
			'/' + self.name + '/'
		end
	end

  # create a mapping of file extensions and counts based on a list of input files from a google bucket
  def self.create_extension_map(files, map={})
		files.map(&:name).each do |name|
			# don't use directories in extension map
			unless name.end_with?('/')
				parts = name.split('.')
				# grab everything after first period as file extension
				ext = parts.size > 2 ? parts[1..parts.size - 1].join('.') : parts.last
				map[ext].nil? ? map[ext] = 1 : map[ext] += 1
			end
		end
		map
	end
end