class DirectoryListing
	include Mongoid::Document
	include Mongoid::Timestamps

	belongs_to :study

	field :name, type: String
	field :description, type: String
	field :files, type: Array
	field :synced, type: Boolean, default: true

	validates_uniqueness_of :name, scope: :study_id

	# check if a directory_listing has a file
	def has_file?(filename)
		!self.files.detect(filename).nil?
	end
end