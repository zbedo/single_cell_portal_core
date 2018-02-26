class ParseUtils

  def self.cell_ranger_expression_parse(study, user, remote_matrix_location, remote_genes_location, remote_barcodes_location)
    begin
      # localize files
      Rails.logger.info "#{Time.now}: Parsing 10X CellRanger source data files for #{study.name}"
      study.make_data_dir
      Rails.logger.info "#{Time.now}: Localizing output files & creating study file entries from 10X CellRanger source data for #{study.name}"
      remote_matrix = Study.firecloud_client.execute_gcloud_method(:get_workspace_file, study.firecloud_project,
                                                                   study.firecloud_workspace, remote_matrix_location)
      remote_genes = Study.firecloud_client.execute_gcloud_method(:get_workspace_file, study.firecloud_project,
                                                                  study.firecloud_workspace, remote_genes_location)
      remote_barcodes = Study.firecloud_client.execute_gcloud_method(:get_workspace_file, study.firecloud_project,
                                                                     study.firecloud_workspace, remote_barcodes_location)

      matrix_file = Study.firecloud_client.execute_gcloud_method(:download_workspace_file, study.firecloud_project,
                                                                 study.firecloud_workspace, remote_matrix_location,
                                                                 study.data_store_path, verify: :none)
      genes_file = Study.firecloud_client.execute_gcloud_method(:download_workspace_file, study.firecloud_project,
                                                                study.firecloud_workspace, remote_genes_location,
                                                                study.data_store_path, verify: :none)
      barcodes_file = Study.firecloud_client.execute_gcloud_method(:download_workspace_file, study.firecloud_project,
                                                                   study.firecloud_workspace, remote_barcodes_location,
                                                                   study.data_store_path, verify: :none)
      matrix_study_file = StudyFile.create!(name: remote_matrix.name, description: 'MM Coordinate Matrix from CellRanger',
                                            study_id: study.id, file_type: 'Expression Matrix', parse_status: 'parsing',
                                            status: 'uploaded', data_dir: study.data_dir, generation: remote_matrix.generation,
                                            upload_file_name: remote_matrix.name, upload_content_type: 'text/plain',
                                            upload_file_size: remote_matrix.size, remote_location: remote_matrix_location)
      genes_study_file =  StudyFile.create!(name: remote_genes.name, description: '10X Genes File from CellRanger', study_id: study.id,
                                            file_type: '10X Genes File', parse_status: 'parsing', status: 'uploaded',
                                            data_dir: study.data_dir, generation: remote_genes.generation,
                                            upload_file_name: remote_genes.name, upload_content_type: 'text/plain',
                                            upload_file_size: remote_genes.size, remote_location: remote_genes_location)
      barcodes_study_file = StudyFile.create!(name: remote_barcodes.name, description: '10X Barcodes File from CellRanger',
                                              study_id: study.id, file_type: '10X Barcodes File', parse_status: 'parsing', status: 'uploaded',
                                              data_dir: study.data_dir, generation: remote_barcodes.generation,
                                              upload_file_name: remote_barcodes.name, upload_content_type: 'text/plain',
                                              upload_file_size: remote_barcodes.size, remote_location: remote_barcodes_location)
      # open files and read contents
      Rails.logger.info "#{Time.now}: Reading gene/barcode/matrix file contents for #{study.name}"
      matrix = NMatrix::IO::Market.load(matrix_file.path)
      genes = genes_file.readlines.map {|line| line.strip.split.last }
      barcodes = barcodes_file.readlines.map(&:strip)
      matrix_file.close
      genes_file.close
      barcodes_file.close

      # load significant data & construct objects
      significant_scores = matrix.to_hash
      @genes = []
      @data_arrays = []
      @count = 0
      @child_count = 0

      Rails.logger.info "#{Time.now}: Creating new gene & data_array records from 10X CellRanger source data  for #{study.name}"

      significant_scores.each do |gene_index, barcode_obj|
        gene_name = genes[gene_index]
        new_gene = Gene.new(study_id: study.id, name: gene_name, searchable_name: gene_name.downcase, study_file_id: matrix_file.id)
        @genes << new_gene.attributes
        gene_barcodes = []
        gene_exp_values = []
        barcode_obj.each do |barcode_index, expression_value|
          gene_barcodes << barcodes[barcode_index]
          gene_exp_values << expression_value
        end

        gene_barcodes.each_slice(DataArray::MAX_ENTRIES).with_index do |slice, index|
          cell_array = DataArray.new(name: new_gene.cell_key, cluster_name: remote_matrix_location, array_type: 'cells',
                                     array_index: index + 1, study_file_id: matrix_study_file.id, values: slice,
                                     linear_data_type: 'Gene', linear_data_id: new_gene.id, study_id: study.id)
          @data_arrays << cell_array.attributes
        end

        gene_exp_values.each_slice(DataArray::MAX_ENTRIES).with_index do |slice, index|
          score_array = DataArray.new(name: new_gene.score_key, cluster_name: remote_matrix_location, array_type: 'expression',
                                      array_index: index + 1, study_file_id: matrix_study_file.id, values: slice,
                                      linear_data_type: 'Gene', linear_data_id: new_gene.id, study_id: study.id)
          @data_arrays << score_array.attributes
        end

        # batch insert records in groups of 1000
        if @genes.size % 1000 == 0
          Gene.create!(@records)
          @count += @genes.size
          Rails.logger.info "#{Time.now}: Processed #{@count} genes from 10X CellRanger source data for #{study.name}"
          @records = []
        end

        if @data_arrays.size >= 1000
          DataArray.create!(@data_arrays)
          @child_count += @data_arrays.size
          Rails.logger.info "#{Time.now}: Processed #{@child_count} child data arrays from 10X CellRanger source data for #{study.name}"
          @data_arrays = []
        end
      end

      # create records
      Gene.create(@genes)
      DataArray.create(@data_arrays)
      barcodes.each_slice(DataArray::MAX_ENTRIES).with_index do |slice, index|
        known_cells = study.data_arrays.build(name: "#{remote_matrix_location} Cells", cluster_name: remote_matrix_location,
                                              array_type: 'cells', array_index: index + 1, values: slice,
                                              study_file_id: matrix_study_file.id, study_id: study.id)
        known_cells.save
      end
      # clean up
      matrix_study_file.remove_local_copy
      genes_study_file.remove_local_copy
      barcodes_study_file.remove_local_copy

      end_time = Time.now
      time = (end_time - start_time).divmod 60.0
      @message << "#{Time.now}: #{study.name} 10X CellRanger expression data parse completed!"
      @message << "Gene-level entries created: #{@count}"
      @message << "Total Time: #{time.first} minutes, #{time.last} seconds"
      Rails.logger.info @message
      begin
        SingleCellMailer.notify_user_parse_complete(user.email, "10X CellRanger expression data has completed parsing", @message).deliver_now
      rescue => e
        Rails.logger.error "#{Time.now}: Unable to deliver email: #{e.message}"
      end

      puts 'Parse complete!'
      puts "Genes created: #{@genes.size}"
      puts "Data Arrays created: #{@data_arrays.size}"
      true
    rescue => e
      # error has occurred, so clean up records and remove file
      Gene.where(study_id: study.id, study_file_id: matrix_study_file.id).delete_all
      DataArray.where(study_id: study.id, study_file_id: matrix_study_file.id).delete_all
      # clean up files
      matrix_study_file.remove_local_copy
      genes_study_file.remove_local_copy
      barcodes_study_file.remove_local_copy
      matrix_study_file.destroy
      genes_study_file.destroy
      barcodes_study_file.destroy
      error_message = e.message
      Rails.logger.error "#{Time.now}: #{error_message}"
      SingleCellMailer.notify_user_parse_fail(user.email, "Gene Expression matrix: '#{filename}' parse has failed", error_message).deliver_now
    end
  end
end