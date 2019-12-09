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

    # upload files and request parse

    # expression matrix #1
    file_params = {study_file: {file_type: 'Expression Matrix', study_id: @study.id.to_s}}
    perform_study_file_upload('expression_matrix_example.txt', file_params, @study.id)
    assert_response 200, "Expression matrix upload failed: #{@response.code}"
    assert @study.expression_matrix_files.size == 1, "Expression matrix failed to associate, found #{@study.expression_matrix_files.size} files"
    expression_matrix_1 = @study.expression_matrix_files.first
    assert_equal 'unparsed', expression_matrix_1.parse_status
    initiate_study_file_parse('expression_matrix_example.txt', @study.id)
    assert_response 200, "Expression matrix parse job failed to start: #{@response.code}"

    sleep_increment = 60
    seconds_slept = 0
    max_seconds_to_sleep = 1200
    while ( expression_matrix_1.parse_status != 'parsed' ) do
      if seconds_slept > max_seconds_to_sleep
        raise "waited #{seconds_slept} for expression_matrix_1.parse_status to be 'parsed', but it's '#{expression_matrix_1.parse_status}'."
      end
      puts "sleeping for #{sleep_increment} seconds (#{seconds_slept}/#{max_seconds_to_sleep} seconds slept so far, expression_matrix_1.parse_status is \"#{expression_matrix_1.parse_status}\")..."
      sleep(sleep_increment)
      seconds_slept += sleep_increment
      expression_matrix_1.reload
    end
    puts "...done sleeping (#{seconds_slept} seconds)"
    assert_equal 'parsed', expression_matrix_1.parse_status

    assert_equal 19, @study.genes.size, 'Did not parse all genes from expression matrix'

    # verify that counts are correct, this will ensure that everything uploaded & parsed correctly
    @study.reload
    gene_count = @study.gene_count
    share_count = @study.study_shares.size

    assert gene_count == 19, "did not find correct number of genes, expected 19 but found #{gene_count}"
    assert share_count == 1, "did not find correct number of study shares, expected 1 but found #{share_count}"

    puts "#{File.basename(__FILE__)}: #{self.method_name} successful!"

  end

end
