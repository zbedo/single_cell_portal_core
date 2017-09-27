require "test_helper"

##
#
# FireCloudClientTest - unit tests for FireCloudClient
# Only covers Service Account level actions (cannot authenticate as user, so no workflow or billing unit tests)
#
##

class FireCloudClientTest < ActiveSupport::TestCase
  def setup
    @fire_cloud_client = FireCloudClient.new
    @test_email = 'singlecelltest@gmail.com'
  end

  ##
  #
  # TOKEN & STATUS TESTS
  #
  ##

  # refresh the FireCloud API access token
  # test only checks expiry date as we can't be sure that the access_token will actually refresh fast enough
  def test_refresh_access_token
    puts "#{File.basename(__FILE__)}: '#{self.method_name}'"

    expires_at = @fire_cloud_client.expires_at
    assert !@fire_cloud_client.access_token_expired?, 'Token should not be expired for new clients'
    new_expiry = @fire_cloud_client.refresh_access_token
    assert new_expiry > expires_at, "Expiration date did not update, #{new_expiry} is not greater than #{expires_at}"

    puts "#{File.basename(__FILE__)}: '#{self.method_name}' successful!"
  end

  # refresh the GCS Driver
  # test only checks issue date as we can't be sure that the storage_access_token will actually refresh fast enough
  def test_refresh_google_storage_driver
    puts "#{File.basename(__FILE__)}: '#{self.method_name}'"

    issued_at = @fire_cloud_client.storage_issued_at
    new_storage = @fire_cloud_client.refresh_storage_driver
    assert new_storage.present?, 'New storage did not get instantiated'

    new_issued_at = new_storage.service.credentials.client.issued_at
    assert new_issued_at > issued_at, "Storage driver did not update, #{new_issued_at} is not greater than #{issued_at}"

    puts "#{File.basename(__FILE__)}: '#{self.method_name}' successful!"
  end

  # assert FireCloud is responding
  def test_firecloud_status
    puts "#{File.basename(__FILE__)}: '#{self.method_name}'"

    # check that API is up
    assert @fire_cloud_client.api_available?, 'FireCloud API is not available'
    firecloud_status = @fire_cloud_client.api_status
    assert firecloud_status['ok'], 'Detailed FireCloud API status is not available'

    puts "#{File.basename(__FILE__)}: '#{self.method_name}' successful!"
  end

  ##
  #
  # WORKSPACE TESTS
  #
  ##

  # test getting workspaces
  def test_workspaces
    puts "#{File.basename(__FILE__)}: '#{self.method_name}'"

    workspaces = @fire_cloud_client.workspaces
    assert workspaces.size > 0, 'Did not find any workspaces'

    puts "#{File.basename(__FILE__)}: '#{self.method_name}' successful!"
  end

  # main workspace test: create, get, set & update acls, delete
  def test_create_and_manage_workspace
    puts "#{File.basename(__FILE__)}: '#{self.method_name}'"

    workspace_name = "test-workspace-#{SecureRandom.uuid}"

    # create workspace
    puts 'creating workspace...'
    workspace = @fire_cloud_client.create_workspace(workspace_name)
    assert workspace['name'] == workspace_name, "Name was not set correctly, expected '#{workspace_name}' but found '#{workspace['name']}'"

    # get workspace
    puts 'retrieving workspace...'
    retrieved_workspace = @fire_cloud_client.get_workspace(workspace_name)
    assert retrieved_workspace.present?, "Did not find requested workspace: #{workspace_name}"

    # set ACL
    puts 'setting workspace acl...'
    acl = @fire_cloud_client.create_workspace_acl(@test_email, 'OWNER')
    updated_workspace = @fire_cloud_client.update_workspace_acl(workspace_name, acl)
    assert updated_workspace['usersUpdated'].size == 1, 'Did not update a user in workspace'

    # retrieve new ACL
    puts 'retrieving workspace acl...'
    ws_acl = @fire_cloud_client.get_workspace_acl(workspace_name)
    assert ws_acl['acl'].keys.include?(@test_email), "Workspace ACL does not contain #{@test_email}"
    assert ws_acl['acl'][@test_email]['accessLevel'] == 'OWNER', "Workspace ACL does not list #{@test_email} as owner"

    # set workspace attribute
    puts 'setting workspace attribute...'
    new_attribute = {
        'random_attribute' => SecureRandom.uuid
    }
    updated_ws_attributes = @fire_cloud_client.set_workspace_attributes(workspace_name, new_attribute)
    assert updated_ws_attributes['attributes'] == new_attribute, "Did not properly set new attribute to workspace, expected '#{new_attribute}' but found '#{updated_ws_attributes['attributes']}'"

    # delete workspace
    puts 'deleting workspace...'
    delete_message = @fire_cloud_client.delete_workspace(workspace_name)
    assert delete_message.has_key?('message'), 'Did not receive a delete confirmation'
    expected_confirmation = "The workspace #{@fire_cloud_client.project}:#{workspace_name} has been un-published."
    assert delete_message['message'].include?(expected_confirmation), "Did not receive correct confirmation, expected '#{expected_confirmation}' but found '#{delete_message['message']}'"

    puts "#{File.basename(__FILE__)}: '#{self.method_name}' successful!"
  end
end