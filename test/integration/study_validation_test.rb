require "integration_test_helper"

class StudyAdminTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @test_user = User.find_by(email: 'testing.user@gmail.com')
    @sharing_user = User.find_by(email: 'sharing.user@gmail.com')
    auth_as_user(@test_user)
    sign_in @test_user
    @random_seed = File.open(Rails.root.join('.random_seed')).read.strip
  end

  # check that file header/format checks still function properly
  test 'should fail all parse jobs' do
    puts "#{File.basename(__FILE__)}: #{self.method_name}"
    study_params = {
        study: {
            name: "Parse Failure Study #{@random_seed}",
            user_id: @test_user.id
        }
    }
    post studies_path, params: study_params
    follow_redirect!
    assert_response 200, "Did not redirect to upload successfully"
    @study = Study.find_by(name: "Parse Failure Study #{@random_seed}")
    assert @study.present?, "Study did not successfully save"
    # upload files and parse manually
    # bad expression matrix
    file_params = {study_file: {file_type: 'Expression Matrix', study_id: @study.id.to_s}}
    perform_study_file_upload('expression_matrix_example_bad.txt', file_params, @study.id)
    assert_response 200, "Expression matrix upload failed: #{@response.code}"
    assert @study.expression_matrix_files.size == 1, "Expression matrix failed to associate, found #{@study.expression_matrix_files.size} files"
    expression_matrix_1 = @study.expression_matrix_files.first
    # this parse has a duplicate gene, which will not throw an error - it is caught internally
    @study.initialize_gene_expression_data(expression_matrix_1, @test_user)

    assert @study.genes.size == 0, "Found #{@study.genes.size} genes when should have found 0"
    assert @study.expression_matrix_files.size == 0,
           "Found #{@study.expression_matrix_files.size} expression matrices when should have found 0"
    # bad metadata file
    file_params = {study_file: {file_type: 'Metadata', study_id: @study.id.to_s}}
    perform_study_file_upload('metadata_bad.txt', file_params, @study.id)
    assert_response 200, "Metadata upload failed: #{@response.code}"
    metadata_study_file = @study.metadata_file
    assert metadata_study_file.present?, "Metadata failed to associate, found no file: #{metadata_study_file.present?}"
    begin
      # this parse is a file header issue, which does throw and error
      @study.initialize_cell_metadata(metadata_study_file, @test_user)
    rescue => e
      assert e.is_a?(StandardError), "Caught unknown error during parse: #{e.class}:#{e.message}"
    end
    assert @study.cell_metadata.size == 0, "Found #{@study.cell_metadata.size} genes when should have found 0"
    assert @study.metadata_file.nil?,
           "Found metadata file when should have found none"
    # bad cluster
    file_params = {study_file: {name: 'Test Cluster 1', file_type: 'Cluster', study_id: @study.id.to_s}}
    perform_study_file_upload('cluster_bad.txt', file_params, @study.id)
    assert_response 200, "Cluster 1 upload failed: #{@response.code}"
    assert @study.cluster_ordinations_files.size == 1, "Cluster 1 failed to associate, found #{@study.cluster_ordinations_files.size} files"
    cluster_file_1 = @study.cluster_ordinations_files.first
    begin
      # this parse is a file header issue, which does throw and error
      @study.initialize_cluster_group_and_data_arrays(cluster_file_1, @test_user)
    rescue => e
      assert e.is_a?(StandardError), "Caught unknown error during parse: #{e.class}:#{e.message}"
    end
    assert @study.cluster_groups.size == 0, "Found #{@study.cluster_groups.size} genes when should have found 0"
    assert @study.cluster_ordinations_files.size == 0,
           "Found #{@study.cluster_ordinations_files.size} cluster files when should have found 0"
    # bad marker gene list
    file_params = {study_file: {name: 'Test Gene List', file_type: 'Gene List', study_id: @study.id.to_s}}
    perform_study_file_upload('marker_1_gene_list_bad.txt', file_params, @study.id)
    assert_response 200, "Gene list upload failed: #{@response.code}"
    assert @study.study_files.where(file_type: 'Gene List').size == 1,
           "Gene list failed to associate, found #{@study.study_files.where(file_type: 'Gene List').size} files"
    gene_list_file = @study.study_files.where(file_type: 'Gene List').first
    # this parse has a duplicate gene, which will not throw an error - it is caught internally
    @study.initialize_precomputed_scores(gene_list_file, @test_user)
    # we have to reload the study because it will have a cached reference to the precomputed_score due to the nature of the parse
    @study = Study.find_by(name: "Parse Failure Study #{@random_seed}")
    assert @study.study_files.where(file_type: 'Gene List').size == 0,
           "Found #{@study.study_files.where(file_type: 'Gene List').size} gene list files when should have found 0"
    assert @study.precomputed_scores.size == 0, "Found #{@study.precomputed_scores.size} precomputed scores when should have found 0"
    puts "#{File.basename(__FILE__)}: #{self.method_name} successful!"
  end

  test 'should prevent changing firecloud attributes' do
    puts "#{File.basename(__FILE__)}: #{self.method_name}"
    study_params = {
        study: {
            name: "FireCloud Attribute Test #{@random_seed}",
            user_id: @test_user.id
        }
    }
    post studies_path, params: study_params
    follow_redirect!
    assert_response 200, "Did not redirect to upload successfully"
    @study = Study.find_by(name: "FireCloud Attribute Test #{@random_seed}")
    assert @study.present?, "Study did not successfully save"

    # test update and expected error messages
    update_params = {
        study: {
            firecloud_workspace: 'this-is-different',
            firecloud_project: 'not-the-same'
        }
    }
    patch study_path(@study.id), params: update_params
    assert_select 'li#study_error_firecloud_project', 'Firecloud project cannot be changed once initialized.'
    assert_select 'li#study_error_firecloud_workspace', 'Firecloud workspace cannot be changed once initialized.'
    # reload study and assert values are unchange
    @study = Study.find_by(name: "FireCloud Attribute Test #{@random_seed}")
    assert_equal FireCloudClient::PORTAL_NAMESPACE, @study.firecloud_project,
                 "FireCloud project was not correct, expected #{FireCloudClient::PORTAL_NAMESPACE} but found #{@study.firecloud_project}"
    assert_equal "test-firecloud-attribute-test-#{@random_seed}", @study.firecloud_workspace,
                 "FireCloud workspace was not correct, expected test-firecloud-attribute-test-#{@random_seed} but found #{@study.firecloud_workspace}"
    puts "#{File.basename(__FILE__)}: #{self.method_name} successful!"
  end

  # this test depends on several of the studies from test/integration/study_creation_test.rb; that suite should be run
  # first before running this test, and without changing the random_seed variable
  test 'should grant access by share permission' do
    puts "#{File.basename(__FILE__)}: #{self.method_name}"
    @test_study = Study.find_by(name: "Test Study #{@random_seed}")
    @private_study = Study.find_by(name: "Private Study #{@random_seed}")
    @gzip_study = Study.find_by(name: "Gzip Parse #{@random_seed}")
    view_private_path = view_study_path(@private_study.url_safe_name)
    view_gzip_path = view_study_path(@gzip_study.url_safe_name)
    edit_test_study_path = study_path(@test_study.id)
    edit_private_study_path = study_path(@private_study.id)

    # sign out of normal test user and auth as the sharing user
    sign_out(@test_user)
    auth_as_user(@sharing_user)
    sign_in(@sharing_user)
    get view_private_path
    assert_redirected_to site_path, "Did not redirect to site path, current path is #{path}"
    get view_gzip_path
    assert_response 200,
                    "Did not correctly load #{view_gzip_path}, expected response 200 but found #{@response.code}"
    assert_equal view_gzip_path, path,
                 "Did not correctly load #{view_gzip_path}, current path is #{path}"

    get edit_private_study_path
    assert_redirected_to studies_path, "Did not redirect to studies path, current path is #{path}"
    follow_redirect!
    assert_equal studies_path, path,
                 "Did not correctly load #{studies_path}, current path is #{path}"

    get edit_test_study_path
    assert_response 200,
                    "Did not correctly load #{edit_test_study_path}, expected response 200 but found #{@response.code}"
    assert_equal edit_test_study_path, path,
                 "Did not correctly load #{edit_test_study_path}, current path is #{path}"
    # upload a file
    file_params = {study_file: {file_type: 'Documentation', study_id: @test_study.id.to_s}}
    perform_study_file_upload('README.txt', file_params, @test_study.id)
    assert_response 200, "Doc file upload failed: #{@response.code}"
    assert @test_study.study_files.where(file_type: 'Documentation').size == 2,
           "Doc failed to associate, found #{@test_study.study_files.where(file_type: 'Documentation').size} files"
    puts "#{File.basename(__FILE__)}: #{self.method_name} successful!"
  end

  test 'should disable downloads for reviewers' do
    puts "#{File.basename(__FILE__)}: #{self.method_name}"
    study_params = {
        study: {
            name: "Reviewer Share #{@random_seed}",
            user_id: @test_user.id,
            public: false,
            study_shares_attributes: {
                "0" => {
                    email: @sharing_user.email,
                    permission: 'Reviewer'
                }
            }
        }
    }
    post studies_path, params: study_params
    follow_redirect!
    assert_response 200, "Did not complete request successfully, expected redirect and response 200 but found #{@response.code}"
    @study = Study.find_by(name: "Reviewer Share #{@random_seed}")
    assert @study.study_shares.size == 1, "Did not successfully create study_share, found #{@study.study_shares.size} shares"
    reviewer_email = @study.study_shares.reviewers.first
    assert reviewer_email == @sharing_user.email, "Did not grant reviewer permission to #{@sharing_user.email}, reviewers: #{reviewer_email}"

    # load private study and validate reviewer can see study but not download data
    sign_out @test_user
    auth_as_user(@sharing_user)
    sign_in @sharing_user
    get view_study_path(@study.url_safe_name)
    assert controller.current_user == @sharing_user,
           "Did not successfully authenticate as sharing user, current_user is #{controller.current_user.email}"
    assert_select "h1.study-lead", true, "Did not successfully load study page for #{@study.name}"
    assert_select 'li#study-download-nav' do |element|
      assert element.attr('class').to_str.include?('disabled'), "Did not disable downloads tab for reviewer: '#{element.attr('class')}'"
    end
    # ensure direct call to download is still disabled
    get download_private_file_path(@study.url_safe_name, filename: 'README.txt')
    follow_redirect!
    assert_equal view_study_path(@study.url_safe_name), path,
                 "Did not block download and redirect to study page, current path is #{path}"
    puts "#{File.basename(__FILE__)}: #{self.method_name} successful!"
  end
end

