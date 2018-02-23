class ParseUtils

  def self.cell_ranger_expression_parse(study, remote_matrix_location, remote_genes_location, remote_barcodes_location)
    # localize files
    study.make_data_dir
    puts 'Localizing files & creating study file entries...'
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
    matrix_study_file = StudyFile.create(name: remote_matrix.name, description: 'MM Coordinate Expression Matrix from CellRanger',
                                         study_id: study.id, file_type: 'Expression Matrix', parse_status: 'parsing',
                                         status: 'uploaded', data_dir: study.data_dir, generation: remote_matrix.generation,
                                         upload_file_name: remote_matrix.name, upload_content_type: 'text/plain',
                                         upload_file_size: remote_matrix.size, remote_location: remote_matrix_location)
    genes_study_file =  StudyFile.create(name: remote_genes.name, description: 'Gene List from CellRanger', study_id: study.id,
                                         file_type: 'Other', parse_status: 'parsing', status: 'uploaded',
                                         data_dir: study.data_dir, generation: remote_genes.generation,
                                         upload_file_name: remote_genes.name, upload_content_type: 'text/plain',
                                         upload_file_size: remote_genes.size, remote_location: remote_genes_location)
    barcodes_study_file = StudyFile.create(name: remote_barcodes.name, description: 'Barcode List from CellRanger',
                                           study_id: study.id, file_type: 'Other', parse_status: 'parsing', status: 'uploaded',
                                           data_dir: study.data_dir, generation: remote_barcodes.generation,
                                           upload_file_name: remote_barcodes.name, upload_content_type: 'text/plain',
                                           upload_file_size: remote_barcodes.size, remote_location: remote_barcodes_location)
    # open files and read contents
    puts 'Reading file contents...'
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

    puts 'Creating new records...'
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

    puts 'Parse complete!'
    puts "Genes created: #{@genes.size}"
    puts "Data Arrays created: #{@data_arrays.size}"
    true
  end
end