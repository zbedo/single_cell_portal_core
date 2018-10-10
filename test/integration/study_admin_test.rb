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

  test 'create default testing study' do
    puts "#{File.basename(__FILE__)}: #{self.method_name}"
    study_params = {
        study: {
            name: "Test Study #{@random_seed}",
            user_id: @test_user.id,
            study_shares_attributes: {
                "0" => {
                    email: @sharing_user.email,
                    permission: 'Edit'
              }
            }
        }
    }
    post studies_path, params: study_params
    follow_redirect!
    assert_response 200, "Did not redirect to upload successfully"
    @study = Study.find_by(name: "Test Study #{@random_seed}")
    assert @study.present?, "Study did not successfully save"
    # upload files and parse manually
    # expression matrix #1
    exp_matrix = Rack::Test::UploadedFile.new(Rails.root.join('test', 'test_data', 'expression_matrix_example.txt'))
    file_params = {study_file: {upload: exp_matrix, file_type: 'Expression Matrix', study_id: @study.id.to_s}}
    patch "/single_cell/studies/#{@study.id}/upload", params: file_params, headers: {'Content-Type' => 'multipart/form-data'}
    assert_response 200, "Expression matrix upload failed: #{@response.code}"
    assert @study.expression_matrix_files.size == 1, "Expression matrix failed to associate, found #{@study.expression_matrix_files.size} files"
    expression_matrix_1 = @study.expression_matrix_files.first
    @study.initialize_gene_expression_data(expression_matrix_1, @test_user)
    assert @study.genes.size > 0, 'Did not parse any genes from expression matrix'
    num_genes = @study.gene_count
    # expression matrix #2
    exp_matrix_2 = Rack::Test::UploadedFile.new(Rails.root.join('test', 'test_data', 'expression_matrix_example_2.txt'))
    file_params = {study_file: {upload: exp_matrix_2, file_type: 'Expression Matrix', study_id: @study.id.to_s}}
    patch "/single_cell/studies/#{@study.id}/upload", params: file_params, headers: {'Content-Type' => 'multipart/form-data'}
    assert_response 200, "Expression matrix upload failed: #{@response.code}"
    assert @study.expression_matrix_files.size == 2, "Expression matrix failed to associate, found #{@study.expression_matrix_files.size} files"
    expression_matrix_2 = @study.expression_matrix_files.last
    @study.initialize_gene_expression_data(expression_matrix_2, @test_user)
    assert @study.genes.size > num_genes, 'Did not parse any genes from 2nd expression matrix'
    # metadata file
    metadata_file = Rack::Test::UploadedFile.new(Rails.root.join('test', 'test_data', 'metadata_example2.txt'))
    file_params = {study_file: {upload: metadata_file, file_type: 'Metadata', study_id: @study.id.to_s}}
    patch "/single_cell/studies/#{@study.id}/upload", params: file_params, headers: {'Content-Type' => 'multipart/form-data'}
    assert_response 200, "Metadata upload failed: #{@response.code}"
    metadata_study_file = @study.metadata_file
    assert metadata_study_file.present?, "Metadata failed to associate, found no file: #{metadata_study_file.present?}"
    @study.initialize_cell_metadata(metadata_study_file, @test_user)
    assert @study.cell_metadata.size > 0, 'Did not parse any cell metadata from metadata file'
    # first cluster
    cluster_upload = Rack::Test::UploadedFile.new(Rails.root.join('test', 'test_data', 'cluster_example_2.txt'))
    file_params = {study_file:
                       {
                           name: 'Test Cluster 1', upload: cluster_upload, file_type: 'Cluster', study_id: @study.id.to_s,
                           study_file_x_axis_min: -100, study_file_x_axis_max: 100, study_file_y_axis_min: -75,
                           study_file_y_axis_max: 75, study_file_z_axis_min: -125, study_file_z_axis_max: 125,
                           study_file_x_axis_label: 'X Axis', study_file_y_axis_label: 'Y Axis', study_file_z_axis_label: 'Z Axis'
                       }
    }
    patch "/single_cell/studies/#{@study.id}/upload", params: file_params, headers: {'Content-Type' => 'multipart/form-data'}
    assert_response 200, "Cluster 1 upload failed: #{@response.code}"
    assert @study.cluster_ordinations_files.size == 1, "Cluster 1 failed to associate, found #{@study.cluster_ordinations_files.size} files"
    cluster_file_1 = @study.cluster_ordinations_files.first
    @study.initialize_cluster_group_and_data_arrays(cluster_file_1, @test_user)
    assert @study.cluster_groups.size == 1, 'Did not parse any clusters from cluster file'
    cluster_1 = @study.cluster_groups.first
    assert DataArray.where(linear_data_id: cluster_1.id, study_id: @study.id).any?, 'Did not parse any data arrays from cluster file'
    # second cluster
    cluster_2_upload = Rack::Test::UploadedFile.new(Rails.root.join('test', 'test_data', 'cluster_2_example_2.txt'))
    file_params = {study_file:
                       {
                           name: 'Test Cluster 2', upload: cluster_2_upload, file_type: 'Cluster', study_id: @study.id.to_s
                       }
    }
    patch "/single_cell/studies/#{@study.id}/upload", params: file_params, headers: {'Content-Type' => 'multipart/form-data'}
    assert_response 200, "Cluster 2 upload failed: #{@response.code}"
    assert @study.cluster_ordinations_files.size == 2, "Cluster 1 failed to associate, found #{@study.cluster_ordinations_files.size} files"
    cluster_file_2 = @study.cluster_ordinations_files.last
    @study.initialize_cluster_group_and_data_arrays(cluster_file_2, @test_user)
    assert @study.cluster_groups.size == 2, 'Did not parse any clusters from 2nd cluster file'
    cluster_2 = @study.cluster_groups.last
    assert DataArray.where(linear_data_id: cluster_2.id, study_id: @study.id).any?, 'Did not parse any data arrays from 2nd cluster file'
    # coordinate labels
    coordinate_label_upload = Rack::Test::UploadedFile.new(Rails.root.join('test', 'test_data', 'coordinate_labels_1.txt'))
    file_params = {study_file:
                       {
                           upload: coordinate_label_upload, file_type: 'Coordinate Labels', study_id: @study.id.to_s,
                           options: {cluster_group_id: cluster_1.id.to_s}
                       }
    }
    patch "/single_cell/studies/#{@study.id}/upload", params: file_params, headers: {'Content-Type' => 'multipart/form-data'}
    assert_response 200, "Coordinate label upload failed: #{@response.code}"
    label_files = @study.study_files.where(file_type: 'Coordinate Labels')
    assert label_files.size == 1, "Coordinate label failed to associate, found #{label_files.size} files"
    coordinate_label_file = label_files.first
    @study.initialize_coordinate_label_data_arrays(coordinate_label_file, @test_user)
    assert DataArray.where(study_id: @study.id, study_file_id: coordinate_label_file.id).any?, 'Did not parse any labels from coordinate label file'
    # fastq 1
    fastq_1_upload = Rack::Test::UploadedFile.new(Rails.root.join('test', 'test_data', 'cell_1_R1_001.fastq.gz'))
    file_params = {study_file: {upload: fastq_1_upload, file_type: 'Fastq', study_id: @study.id.to_s}}
    patch "/single_cell/studies/#{@study.id}/upload", params: file_params, headers: {'Content-Type' => 'multipart/form-data'}
    assert_response 200, "Fastq 1 upload failed: #{@response.code}"
    assert @study.study_files.where(file_type: 'Fastq').size == 1,
           "Fastq 1 failed to associate, found #{@study.study_files.where(file_type: 'Fastq').size} files"
    # fastq 2
    fastq_2_upload = Rack::Test::UploadedFile.new(Rails.root.join('test', 'test_data', 'cell_1_I1_001.fastq.gz'))
    file_params = {study_file: {upload: fastq_2_upload, file_type: 'Fastq', study_id: @study.id.to_s}}
    patch "/single_cell/studies/#{@study.id}/upload", params: file_params, headers: {'Content-Type' => 'multipart/form-data'}
    assert_response 200, "Fastq 2 upload failed: #{@response.code}"
    assert @study.study_files.where(file_type: 'Fastq').size == 2,
           "Fastq 2 failed to associate, found #{@study.study_files.where(file_type: 'Fastq').size} files"
    # marker gene list
    marker_list_upload = Rack::Test::UploadedFile.new(Rails.root.join('test', 'test_data', 'marker_1_gene_list.txt'))
    file_params = {study_file:
                       {
                           name: 'Test Gene List', upload: marker_list_upload, file_type: 'Gene List', study_id: @study.id.to_s
                       }
    }
    patch "/single_cell/studies/#{@study.id}/upload", params: file_params, headers: {'Content-Type' => 'multipart/form-data'}
    assert_response 200, "Gene list upload failed: #{@response.code}"
    assert @study.study_files.where(file_type: 'Gene List').size == 1,
           "Gene list failed to associate, found #{@study.study_files.where(file_type: 'Gene List').size} files"
    gene_list_file = @study.study_files.where(file_type: 'Gene List').first
    @study.initialize_precomputed_scores(gene_list_file, @test_user)
    assert @study.precomputed_scores.any?, 'Did not parse any precomputed scores from gene list'
    # doc file
    doc_upload = Rack::Test::UploadedFile.new(Rails.root.join('test', 'test_data', 'table_1.xlsx'))
    file_params = {study_file: {upload: doc_upload, file_type: 'Documentation', study_id: @study.id.to_s}}
    patch "/single_cell/studies/#{@study.id}/upload", params: file_params, headers: {'Content-Type' => 'multipart/form-data'}
    assert_response 200, "Doc file upload failed: #{@response.code}"
    assert @study.study_files.where(file_type: 'Documentation').size == 1,
           "Fastq 1 failed to associate, found #{@study.study_files.where(file_type: 'Documentation').size} files"

    # verify that counts are correct, this will ensure that everything uploaded & parsed correctly
    cell_count = @study.cell_count
    gene_count = @study.gene_count
    cluster_count = @study.cluster_groups.size
    gene_list_count = @study.study_files.where(file_type: 'Gene List').size
    metadata_count = @study.cell_metadata.size
    cluster_annot_count = @study.cluster_annotation_count
    study_file_count = @study.study_files.non_primary_data.size
    primary_data_count = @study.primary_data_file_count
    share_count = @study.study_shares.size

    assert cell_count == 30, "did not find correct number of cells, expected 30 but found #{cell_count}"
    assert gene_count == 19, "did not find correct number of genes, expected 19 but found #{gene_count}"
    assert cluster_count == 2, "did not find correct number of clusters, expected 2 but found #{cluster_count}"
    assert gene_list_count == 1, "did not find correct number of gene lists, expected 1 but found #{gene_list_count}"
    assert metadata_count == 3, "did not find correct number of metadata objects, expected 3 but found #{metadata_count}"
    assert cluster_annot_count == 3, "did not find correct number of cluster annotations, expected 2 but found #{cluster_annot_count}"
    assert study_file_count == 8, "did not find correct number of study files, expected 8 but found #{study_file_count}"
    assert primary_data_count == 2, "did not find correct number of primary data files, expected 2 but found #{primary_data_count}"
    assert share_count == 1, "did not find correct number of study shares, expected 1 but found #{share_count}"
    puts "#{File.basename(__FILE__)}: #{self.method_name} successful!"
  end

  test 'create 2-d testing study' do
    puts "#{File.basename(__FILE__)}: #{self.method_name}"
    study_params = {
        study: {
            name: "twod Study #{@random_seed}",
            user_id: @test_user.id,
            study_shares_attributes: {
                "0" => {
                    email: @sharing_user.email,
                    permission: 'Edit'
                }
            }
        }
    }
    post studies_path, params: study_params
    follow_redirect!
    assert_response 200, "Did not redirect to upload successfully"
    @study = Study.find_by(name: "twod Study #{@random_seed}")
    assert @study.present?, "Study did not successfully save"
    # upload files and parse manually
    # expression matrix #1
    exp_matrix = Rack::Test::UploadedFile.new(Rails.root.join('test', 'test_data', 'expression_matrix_example.txt'))
    file_params = {study_file: {upload: exp_matrix, file_type: 'Expression Matrix', study_id: @study.id.to_s}}
    patch "/single_cell/studies/#{@study.id}/upload", params: file_params, headers: {'Content-Type' => 'multipart/form-data'}
    assert_response 200, "Expression matrix upload failed: #{@response.code}"
    assert @study.expression_matrix_files.size == 1, "Expression matrix failed to associate, found #{@study.expression_matrix_files.size} files"
    expression_matrix_1 = @study.expression_matrix_files.first
    @study.initialize_gene_expression_data(expression_matrix_1, @test_user)
    assert @study.genes.size > 0, 'Did not parse any genes from expression matrix'
    # metadata file
    metadata_file = Rack::Test::UploadedFile.new(Rails.root.join('test', 'test_data', 'metadata_example.txt'))
    file_params = {study_file: {upload: metadata_file, file_type: 'Metadata', study_id: @study.id.to_s}}
    patch "/single_cell/studies/#{@study.id}/upload", params: file_params, headers: {'Content-Type' => 'multipart/form-data'}
    assert_response 200, "Metadata upload failed: #{@response.code}"
    metadata_study_file = @study.metadata_file
    assert metadata_study_file.present?, "Metadata failed to associate, found no file: #{metadata_study_file.present?}"
    @study.initialize_cell_metadata(metadata_study_file, @test_user)
    assert @study.cell_metadata.size > 0, 'Did not parse any cell metadata from metadata file'
    # first cluster
    cluster_upload = Rack::Test::UploadedFile.new(Rails.root.join('test', 'test_data', 'cluster_2d_example.txt'))
    file_params = {study_file:
                       {
                           name: 'Test Cluster 1', upload: cluster_upload, file_type: 'Cluster', study_id: @study.id.to_s
                       }
    }
    patch "/single_cell/studies/#{@study.id}/upload", params: file_params, headers: {'Content-Type' => 'multipart/form-data'}
    assert_response 200, "Cluster 1 upload failed: #{@response.code}"
    assert @study.cluster_ordinations_files.size == 1, "Cluster 1 failed to associate, found #{@study.cluster_ordinations_files.size} files"
    cluster_file_1 = @study.cluster_ordinations_files.first
    @study.initialize_cluster_group_and_data_arrays(cluster_file_1, @test_user)
    assert @study.cluster_groups.size == 1, 'Did not parse any clusters from cluster file'
    cluster_1 = @study.cluster_groups.first
    assert DataArray.where(linear_data_id: cluster_1.id, study_id: @study.id).any?, 'Did not parse any data arrays from cluster file'
    # marker gene list
    marker_list_upload = Rack::Test::UploadedFile.new(Rails.root.join('test', 'test_data', 'marker_1_gene_list.txt'))
    file_params = {study_file:
                       {
                           name: 'Test Gene List', upload: marker_list_upload, file_type: 'Gene List', study_id: @study.id.to_s
                       }
    }
    patch "/single_cell/studies/#{@study.id}/upload", params: file_params, headers: {'Content-Type' => 'multipart/form-data'}
    assert_response 200, "Gene list upload failed: #{@response.code}"
    assert @study.study_files.where(file_type: 'Gene List').size == 1,
           "Gene list failed to associate, found #{@study.study_files.where(file_type: 'Gene List').size} files"
    gene_list_file = @study.study_files.where(file_type: 'Gene List').first
    @study.initialize_precomputed_scores(gene_list_file, @test_user)
    assert @study.precomputed_scores.any?, 'Did not parse any precomputed scores from gene list'

    # assert all 4 parses completed
    study_file_count = @study.study_files.non_primary_data.size
    assert study_file_count == 4, "did not find correct number of study files, expected 4 but found #{study_file_count}"
    puts "#{File.basename(__FILE__)}: #{self.method_name} successful!"
  end
end
