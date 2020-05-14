require "test_helper"

class UserAssetServiceTest < ActiveSupport::TestCase

  TEST_DATA_DIR = Rails.root.join('test', 'test_data', 'branding_groups')
  TEST_FILES = UserAssetService.get_directory_entries(TEST_DATA_DIR)

  # seed test data into public directory
  # will not overwrite existing data if there, but in that case the test for pulling remote data will fail
  # only intended for use in a CI environment
  def populate_test_data
    UserAssetService::ASSET_PATHS_BY_TYPE.values.each do |asset_path|
      unless Dir.exists?(asset_path)
        FileUtils.mkdir_p(asset_path)
      end
      entries = UserAssetService.get_directory_entries(asset_path)
      if entries.empty?
        TEST_FILES.each_with_index do |test_file, index|
          upload_dir = asset_path.join(index.to_s)
          FileUtils.mkdir_p(upload_dir)
          new_path = upload_dir.join(test_file)
          source_file = TEST_DATA_DIR.join(test_file)
          FileUtils.copy_file(source_file, new_path, preserve: true)
        end
      end
    end
  end

  test 'should instantiate client' do
    puts "#{File.basename(__FILE__)}: #{self.method_name}"

    storage_service = UserAssetService.storage_service
    assert storage_service.present?, 'Did not initialize storage service'
    # validate we're using the same service and not re-initializing every time
    new_service = UserAssetService.storage_service
    service_token = new_service.service.credentials.client.access_token
    issue_date = new_service.service.credentials.client.issued_at

    assert_equal UserAssetService.access_token, service_token
                 "Access tokens are not the same: #{UserAssetService.access_token} != #{service_token}"
    assert_equal UserAssetService.issued_at, issue_date,
                 "Creation timestamps are not the same: #{UserAssetService.issued_at} != #{issue_date}"

    puts "#{File.basename(__FILE__)}: #{self.method_name} successful!"
  end

  test 'should get storage bucket' do
    puts "#{File.basename(__FILE__)}: #{self.method_name}"

    bucket = UserAssetService.get_storage_bucket
    assert bucket.present?, "Did not get storage bucket"
    assert_equal UserAssetService::STORAGE_BUCKET_NAME, bucket.name,
                 "Incorrect bucket returned; should have been #{UserAssetService::STORAGE_BUCKET_NAME} but found #{bucket.name}"

    puts "#{File.basename(__FILE__)}: #{self.method_name} successful!"
  end

  test 'should push and pull assets from remote' do
    puts "#{File.basename(__FILE__)}: #{self.method_name}"

    # seed test data into directory so we have idempotent results
    populate_test_data
    local_assets = UserAssetService.get_local_assets
    assert_equal 9, local_assets.size,
                 "Did not find correct number of files, expected 9 but found #{local_assets.size}"
    filenames = local_assets.map {|asset| asset.basename.to_s}.uniq
    assert_equal TEST_FILES.sort, filenames.sort,
                 "Did not find correct files; expected #{TEST_FILES.sort} but found #{filenames.sort}"

    # do remote push
    pushed = UserAssetService.push_assets_to_remote
    assert pushed, "Did not successfully push assets to remote bucket"
    remote_assets = UserAssetService.get_remote_assets
    assert_equal 9, remote_assets.size,
                 "Did not find correct number of remote assets, expected 9 but found #{remote_assets.size}"

    # now remote local assets and pull from remote
    local_assets.each {|asset| File.delete(asset) }
    new_local_assets = UserAssetService.localize_assets_from_remote
    assert_equal local_assets.sort, new_local_assets.sort,
                 "Did not successfully localize remotes, #{new_local_assets.sort} != #{local_assets.sort}"

    puts "#{File.basename(__FILE__)}: #{self.method_name} successful!"
  end
end
