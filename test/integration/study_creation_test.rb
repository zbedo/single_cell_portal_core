require "integration_test_helper"

class StudyCreationTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @test_user = User.find_by(email: 'testing.user@gmail.com')
    @sharing_user = User.find_by(email: 'sharing.user@gmail.com')
    auth_as_user(@test_user)
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
    file_params = {study_file: {file_type: 'Expression Matrix', study_id: @study.id.to_s}}
    perform_study_file_upload('expression_matrix_example.txt', file_params, @study.id)
    assert_response 200, "Expression matrix upload failed: #{@response.code}"
    assert @study.expression_matrix_files.size == 1, "Expression matrix failed to associate, found #{@study.expression_matrix_files.size} files"
    expression_matrix_1 = @study.expression_matrix_files.first
    expression_matrix_1.reload
    assert expression_matrix_1.parse_status == 'unparsed'
    perform_study_file_parse('expression_matrix_example.txt', @study.id)
    assert_response 200, "Expression matrix parse job failed to start: #{@response.code}"

    sleep_increment = 60
    seconds_slept = 0
    max_seconds_to_sleep = 1200
    while ( assert expression_matrix_1.parse_status != 'parsed' ) do
      if seconds_slept > max_seconds_to_sleep then
        raise "waited #{seconds_slept} for expression_matrix_1.parse_status to be 'parsed', but it's '#{expression_matrix_1.parse_status}'."
      end
      puts "sleeping for #{sleep_increment} seconds (#{seconds_slept}/#{max_seconds_to_sleep} seconds slept so far, expression_matrix_1.parse_status is \"#{expression_matrix_1.parse_status}\")..."
      sleep(sleep_increment)
      seconds_slept += sleep_increment
      expression_matrix_1.reload
    end
    puts "...done sleeping (#{seconds_slept} seconds, expression_matrix_1.parse_status is \"#{expression_matrix_1.parse_status}\")."
    assert expression_matrix_1.parse_status == 'parsed'

    assert @study.genes.size > 0, 'Did not parse any genes from expression matrix'
    num_genes = @study.gene_count

    # verify that counts are correct, this will ensure that everything uploaded & parsed correctly
    gene_count = @study.gene_count
    share_count = @study.study_shares.size

    assert gene_count == 19, "did not find correct number of genes, expected 19 but found #{gene_count}"
    assert share_count == 1, "did not find correct number of study shares, expected 1 but found #{share_count}"
    puts "#{File.basename(__FILE__)}: #{self.method_name} successful!"

  end

# test 'create 2-d testing study' do
#   puts "#{File.basename(__FILE__)}: #{self.method_name}"
#   study_params = {
#       study: {
#           name: "twod Study #{@random_seed}",
#           user_id: @test_user.id,
#           study_shares_attributes: {
#               "0" => {
#                   email: @sharing_user.email,
#                   permission: 'Edit'
#               }
#           }
#       }
#   }
#   post studies_path, params: study_params
#   follow_redirect!
#   assert_response 200, "Did not redirect to upload successfully"
#   @study = Study.find_by(name: "twod Study #{@random_seed}")
#   assert @study.present?, "Study did not successfully save"
#   # upload files and parse manually
#   # expression matrix
#   file_params = {study_file: {file_type: 'Expression Matrix', study_id: @study.id.to_s}}
#   perform_study_file_upload('expression_matrix_example.txt', file_params, @study.id)
#   assert_response 200, "Expression matrix upload failed: #{@response.code}"
#   assert @study.expression_matrix_files.size == 1, "Expression matrix failed to associate, found #{@study.expression_matrix_files.size} files"
#   expression_matrix_1 = @study.expression_matrix_files.first
#   @study.initialize_gene_expression_data(expression_matrix_1, @test_user)
#   assert @study.genes.size > 0, 'Did not parse any genes from expression matrix'
#   # metadata file
#   file_params = {study_file: {file_type: 'Metadata', study_id: @study.id.to_s}}
#   perform_study_file_upload('metadata_example.txt', file_params, @study.id)
#   assert_response 200, "Metadata upload failed: #{@response.code}"
#   metadata_study_file = @study.metadata_file
#   assert metadata_study_file.present?, "Metadata failed to associate, found no file: #{metadata_study_file.present?}"
#   @study.initialize_cell_metadata(metadata_study_file, @test_user)
#   assert @study.cell_metadata.size > 0, 'Did not parse any cell metadata from metadata file'
#   # first cluster
#   file_params = {study_file: {name: 'Test Cluster 1', file_type: 'Cluster', study_id: @study.id.to_s}}
#   perform_study_file_upload('cluster_2d_example.txt', file_params, @study.id)
#   assert_response 200, "Cluster 1 upload failed: #{@response.code}"
#   assert @study.cluster_ordinations_files.size == 1, "Cluster 1 failed to associate, found #{@study.cluster_ordinations_files.size} files"
#   cluster_file_1 = @study.cluster_ordinations_files.first
#   @study.initialize_cluster_group_and_data_arrays(cluster_file_1, @test_user)
#   assert @study.cluster_groups.size == 1, 'Did not parse any clusters from cluster file'
#   cluster_1 = @study.cluster_groups.first
#   assert DataArray.where(linear_data_id: cluster_1.id, study_id: @study.id).any?, 'Did not parse any data arrays from cluster file'
#   # marker gene list
#   file_params = {study_file: {name: 'Test Gene List', file_type: 'Gene List', study_id: @study.id.to_s}}
#   perform_study_file_upload('marker_1_gene_list.txt', file_params, @study.id)
#   assert_response 200, "Gene list upload failed: #{@response.code}"
#   assert @study.study_files.where(file_type: 'Gene List').size == 1,
#          "Gene list failed to associate, found #{@study.study_files.where(file_type: 'Gene List').size} files"
#   gene_list_file = @study.study_files.where(file_type: 'Gene List').first
#   @study.initialize_precomputed_scores(gene_list_file, @test_user)
#   assert @study.precomputed_scores.any?, 'Did not parse any precomputed scores from gene list'

#   # assert all 4 parses completed
#   study_file_count = @study.study_files.non_primary_data.size
#   assert study_file_count == 4, "did not find correct number of study files, expected 4 but found #{study_file_count}"
#   puts "#{File.basename(__FILE__)}: #{self.method_name} successful!"
# end

# test 'create private testing study' do
#   puts "#{File.basename(__FILE__)}: #{self.method_name}"
#   study_params = {
#       study: {
#           name: "Private Study #{@random_seed}",
#           user_id: @test_user.id,
#           public: false
#       }
#   }
#   post studies_path, params: study_params
#   follow_redirect!
#   assert_response 200, "Did not redirect to upload successfully"
#   @study = Study.find_by(name: "Private Study #{@random_seed}")
#   assert @study.present?, "Study did not successfully save"
#   # upload files and parse manually
#   # expression matrix
#   file_params = {study_file: {file_type: 'Expression Matrix', study_id: @study.id.to_s}}
#   perform_study_file_upload('expression_matrix_example.txt', file_params, @study.id)
#   assert_response 200, "Expression matrix upload failed: #{@response.code}"
#   assert @study.expression_matrix_files.size == 1, "Expression matrix failed to associate, found #{@study.expression_matrix_files.size} files"
#   expression_matrix_1 = @study.expression_matrix_files.first
#   @study.initialize_gene_expression_data(expression_matrix_1, @test_user)
#   assert @study.genes.size > 0, 'Did not parse any genes from expression matrix'
#   # metadata file
#   file_params = {study_file: {file_type: 'Metadata', study_id: @study.id.to_s}}
#   perform_study_file_upload('metadata_example.txt', file_params, @study.id)
#   assert_response 200, "Metadata upload failed: #{@response.code}"
#   metadata_study_file = @study.metadata_file
#   assert metadata_study_file.present?, "Metadata failed to associate, found no file: #{metadata_study_file.present?}"
#   @study.initialize_cell_metadata(metadata_study_file, @test_user)
#   assert @study.cell_metadata.size > 0, 'Did not parse any cell metadata from metadata file'
#   # first cluster
#   file_params = {study_file: {name: 'Test Cluster 1', file_type: 'Cluster', study_id: @study.id.to_s}}
#   perform_study_file_upload('cluster_example.txt', file_params, @study.id)
#   assert_response 200, "Cluster 1 upload failed: #{@response.code}"
#   assert @study.cluster_ordinations_files.size == 1, "Cluster 1 failed to associate, found #{@study.cluster_ordinations_files.size} files"
#   cluster_file_1 = @study.cluster_ordinations_files.first
#   @study.initialize_cluster_group_and_data_arrays(cluster_file_1, @test_user)
#   assert @study.cluster_groups.size == 1, 'Did not parse any clusters from cluster file'
#   cluster_1 = @study.cluster_groups.first
#   assert DataArray.where(linear_data_id: cluster_1.id, study_id: @study.id).any?, 'Did not parse any data arrays from cluster file'
#   # marker gene list
#   file_params = {study_file: {name: 'Test Gene List', file_type: 'Gene List', study_id: @study.id.to_s}}
#   perform_study_file_upload('marker_1_gene_list.txt', file_params, @study.id)
#   assert_response 200, "Gene list upload failed: #{@response.code}"
#   assert @study.study_files.where(file_type: 'Gene List').size == 1,
#          "Gene list failed to associate, found #{@study.study_files.where(file_type: 'Gene List').size} files"
#   gene_list_file = @study.study_files.where(file_type: 'Gene List').first
#   @study.initialize_precomputed_scores(gene_list_file, @test_user)
#   assert @study.precomputed_scores.any?, 'Did not parse any precomputed scores from gene list'
#   # readme file
#   file_params = {study_file: {file_type: 'Documentation', study_id: @study.id.to_s}}
#   perform_study_file_upload('README.txt', file_params, @study.id)
#   assert_response 200, "Doc file upload failed: #{@response.code}"
#   assert @study.study_files.where(file_type: 'Documentation').size == 1,
#          "Doc failed to associate, found #{@study.study_files.where(file_type: 'Documentation').size} files"


#   # assert all 4 parses completed
#   study_file_count = @study.study_files.non_primary_data.size
#   assert study_file_count == 5, "did not find correct number of study files, expected 5 but found #{study_file_count}"
#   puts "#{File.basename(__FILE__)}: #{self.method_name} successful!"
# end

# test 'create gzip testing study' do
#   puts "#{File.basename(__FILE__)}: #{self.method_name}"
#   study_params = {
#       study: {
#           name: "Gzip Parse #{@random_seed}",
#           user_id: @test_user.id
#       }
#   }
#   post studies_path, params: study_params
#   follow_redirect!
#   assert_response 200, "Did not redirect to upload successfully"
#   @study = Study.find_by(name: "Gzip Parse #{@random_seed}")
#   assert @study.present?, "Study did not successfully save"
#   # upload files and parse manually
#   # gzip expression matrix
#   file_params = {study_file: {file_type: 'Expression Matrix', study_id: @study.id.to_s}}
#   perform_study_file_upload('expression_matrix_example_gzipped.txt.gz', file_params, @study.id)
#   assert_response 200, "Expression matrix upload failed: #{@response.code}"
#   assert @study.expression_matrix_files.size == 1, "Expression matrix failed to associate, found #{@study.expression_matrix_files.size} files"
#   expression_matrix_1 = @study.expression_matrix_files.first
#   @study.initialize_gene_expression_data(expression_matrix_1, @test_user)
#   assert @study.genes.size > 0, 'Did not parse any genes from expression matrix'
#   study_file_count = @study.expression_matrix_files.size
#   assert study_file_count == 1, "did not find correct number of study files, expected 4 but found #{study_file_count}"
#   assert @study.genes.count == 19, "Did not parse correct number of genes, expected 20 but found #{@study.genes.count}"
#   puts "#{File.basename(__FILE__)}: #{self.method_name} successful!"
# end

# test 'create R-format expression testing study' do
#   puts "#{File.basename(__FILE__)}: #{self.method_name}"
#   study_params = {
#       study: {
#           name: "R-Format Expression Parse #{@random_seed}",
#           user_id: @test_user.id
#       }
#   }
#   post studies_path, params: study_params
#   follow_redirect!
#   assert_response 200, "Did not redirect to upload successfully"
#   @study = Study.find_by(name: "R-Format Expression Parse #{@random_seed}")
#   assert @study.present?, "Study did not successfully save"
#   # upload files and parse manually
#   # R-format expression matrix
#   file_params = {study_file: {file_type: 'Expression Matrix', study_id: @study.id.to_s}}
#   perform_study_file_upload('R_format_text.txt', file_params, @study.id)
#   assert_response 200, "Expression matrix upload failed: #{@response.code}"
#   assert @study.expression_matrix_files.size == 1, "Expression matrix failed to associate, found #{@study.expression_matrix_files.size} files"
#   expression_matrix_1 = @study.expression_matrix_files.first
#   @study.initialize_gene_expression_data(expression_matrix_1, @test_user)
#   assert @study.genes.size > 0, 'Did not parse any genes from expression matrix'
#   study_file_count = @study.expression_matrix_files.size
#   assert study_file_count == 1, "did not find correct number of study files, expected 1 but found #{study_file_count}"
#   assert @study.genes.count == 10, "Did not parse correct number of genes, expected 10 but found #{@study.genes.count}"
#   puts "#{File.basename(__FILE__)}: #{self.method_name} successful!"
# end

# test 'create study file bundle' do
#   puts "#{File.basename(__FILE__)}: #{self.method_name}"
#   study_params = {
#       study: {
#           name: "File Bundle #{@random_seed}",
#           user_id: @test_user.id
#       }
#   }
#   post studies_path, params: study_params
#   follow_redirect!
#   assert_response 200, "Did not redirect to upload successfully"
#   @study = Study.find_by(name: "File Bundle #{@random_seed}")
#   assert @study.present?, "Study did not successfully save"
#   # upload files and parse manually
#   # mm coordinate expression matrix
#   file_params = {study_file: {file_type: 'MM Coordinate Matrix', study_id: @study.id.to_s}}
#   perform_study_file_upload('GRCh38/test_matrix.mtx', file_params, @study.id)
#   assert_response 200, "Expression matrix upload failed: #{@response.code}"
#   assert @study.expression_matrix_files.size == 1, "Expression matrix failed to associate, found #{@study.expression_matrix_files.size} files"

#   # call retrieve_wizard_upload endpoint as this initializes the study_file_bundle (normal flow of upload for MM coordinate matrices)
#   coordinate_matrix = @study.expression_matrix_files.first
#   get retrieve_wizard_upload_study_path(@study.id, file: 'test_matrix.mtx', selector: "expression_form_#{coordinate_matrix.id}",
#                                         partial: 'initialize_expression_form'), xhr: true
#   study_file_bundle = @study.study_file_bundles.first
#   assert study_file_bundle.present?, 'StudyFileBundle did not initialize properly'
#   assert study_file_bundle.parent.id == coordinate_matrix.id,
#          "Did not properly associate coordinate matrix with bundle, expected parent ID of #{coordinate_matrix.id} but found #{study_file_bundle.parent.id}"

#   # upload genes & barcodes files
#   file_params = {study_file: {file_type: '10X Genes File', study_id: @study.id.to_s, study_file_bundle_id: study_file_bundle.id.to_s}}
#   perform_study_file_upload('GRCh38/test_genes.tsv', file_params, @study.id)
#   file_params = {study_file: {file_type: '10X Barcodes File', study_id: @study.id.to_s, study_file_bundle_id: study_file_bundle.id.to_s}}
#   perform_study_file_upload('GRCh38/barcodes.tsv', file_params, @study.id)
#   genes_file = @study.study_files.where(file_type: '10X Genes File').first
#   assert genes_file.present?, 'Did not find genes file after upload'
#   barcodes_file = @study.study_files.where(file_type: '10X Barcodes File').first
#   assert barcodes_file.present?, 'Did not find genes file after upload'

#   # validate that the study_file_bundle has initialized successfully
#   updated_bundle = @study.study_file_bundles.first
#   # this is a hack, but the final assertion will always fail as we aren't performing uploads in test, so we have to
#   # trick the test into thinking that they're uploaded
#   updated_bundle.study_files.update_all(status: 'uploaded')
#   assert updated_bundle.original_file_list.size == 3,
#          "Did not find correct number of files in original_file_list, expected 3 but found #{updated_bundle.original_file_list.size}"
#   assert updated_bundle.study_files.size == 3,
#          "Associations did not set correctly on study_file_bundle, expected 3 but found #{updated_bundle.study_files.size}"
#   assert updated_bundle.completed?, "Bundle did not successfully initialize, expected completed? to be true but found #{updated_bundle.completed?}"

#   # parse data
#   ParseUtils.cell_ranger_expression_parse(@study, @test_user, coordinate_matrix, genes_file, barcodes_file, {skip_upload: true})
#   assert @study.genes.size == 100, "Did not parse correct number of genes, expected 100 but found #{@study.genes.size}"

#   # delete a bundled file (must call DeleteQueueJob manually as delayed_job isn't running)
#   DeleteQueueJob.new(genes_file).perform
#   assert @study.genes.size == 0, "Did not delete parsed data when removing bundled file, expected 0 but found #{@study.genes.size}"
#   # reload the bundle and assert it is no longer completed
#   incomplete_bundle = @study.study_file_bundles.first
#   assert !incomplete_bundle.completed?, "Incomplete undle still shows as completed: #{incomplete_bundle.completed?}"

#   # delete parent file to confirm complete deletion
#   DeleteQueueJob.new(coordinate_matrix).perform
#   assert @study.study_file_bundles.count == 0, "Study file bundle is still present; expected 0 but found #{@study.study_file_bundles.count}"
#   assert @study.study_files.where(queued_for_deletion: false).size == 0, "Did not remove all files, expected 0 but found #{@study.study_files.where(queued_for_deletion: false).size}"
#   puts "#{File.basename(__FILE__)}: #{self.method_name} successful!"
# end

# test 'create embargoed study' do
#   puts "#{File.basename(__FILE__)}: #{self.method_name}"
#   study_params = {
#       study: {
#           name: "Embargo Study #{@random_seed}",
#           user_id: @test_user.id,
#           embargo: (Date.today + 1).to_s
#       }
#   }
#   post studies_path, params: study_params
#   follow_redirect!
#   assert_response 200, "Did not redirect to upload successfully"
#   @study = Study.find_by(name: "Embargo Study #{@random_seed}")
#   assert @study.present?, "Study did not successfully save"
#   # upload files and parse manually
#   # expression matrix #1
#   file_params = {study_file: {file_type: 'Expression Matrix', study_id: @study.id.to_s}}
#   perform_study_file_upload('expression_matrix_example.txt', file_params, @study.id)
#   assert_response 200, "Expression matrix upload failed: #{@response.code}"
#   assert @study.expression_matrix_files.size == 1, "Expression matrix failed to associate, found #{@study.expression_matrix_files.size} files"

#   # check that embargo functionality is working
#   assert @study.embargoed?(@sharing_user),
#          "Study should be embargoed for non-shared user, expected @study.embargoed?(@sharing_user) = true but found #{@study.embargoed?(@sharing_user)}"
#   assert !@study.embargoed?(@test_user),
#          "Study should not be embargoed for owner, expected !@study.embargoed?(@test_user) = true but found #{!@study.embargoed?(@test_user)}"
#   puts "#{File.basename(__FILE__)}: #{self.method_name} successful!"
# end
end
