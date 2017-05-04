require "test_helper"

class DirectoryListingTest < ActiveSupport::TestCase
  def directory_listing
    @directory_listing ||= DirectoryListing.new
  end
end
