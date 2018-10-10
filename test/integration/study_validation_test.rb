require "integration_test_helper"

class StudyAdminTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @test_user = User.find_by(email: 'testing.user@gmail.com')
    @sharing_user = User.find_by(email: 'sharing.user@gmail.com')
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new({
                                                                           :provider => 'google_oauth2',
                                                                           :uid => '123545',
                                                                           :email => 'testing.user@gmail.com'
                                                                       })
    sign_in @test_user
    @random_seed = File.open(Rails.root.join('.random_seed')).read.strip
  end

  # check that file header/format checks still function properly
  test 'parse integrity check' do
    puts "#{File.basename(__FILE__)}: #{self.method_name}"
    study_params = {
        study: {
            name: "Parse Failure Study #{@random_seed}",
            user_id: @test_user.id,
            public: false
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
    @study.initialize_cell_metadata(metadata_study_file, @test_user)
    assert @study.cell_metadata.size == 0, "Found #{@study.cell_metadata.size} genes when should have found 0"
    assert @study.metadata_file.nil?,
           "Found metadata file when should have found none"
    # bad cluster
    file_params = {study_file: {name: 'Test Cluster 1', file_type: 'Cluster', study_id: @study.id.to_s}}
    perform_study_file_upload('cluster_bad.txt', file_params, @study.id)
    assert_response 200, "Cluster 1 upload failed: #{@response.code}"
    assert @study.cluster_ordinations_files.size == 1, "Cluster 1 failed to associate, found #{@study.cluster_ordinations_files.size} files"
    cluster_file_1 = @study.cluster_ordinations_files.first
    @study.initialize_cluster_group_and_data_arrays(cluster_file_1, @test_user)
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
    @study.initialize_precomputed_scores(gene_list_file, @test_user)
    assert @study.precomputed_scores.size == 0, "Found #{@study.precomputed_scores.size} precomputed scores when should have found 0"
    assert @study.study_files.where(file_type: 'Gene List').size == 0,
           "Found #{@study.study_files.where(file_type: 'Gene List').size} gene list files when should have found 0"
    puts "#{File.basename(__FILE__)}: #{self.method_name} successful!"
  end
end

