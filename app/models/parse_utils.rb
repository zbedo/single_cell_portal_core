class ParseUtils

  def self.cell_ranger_expression_parse(study, user, matrix_study_file, genes_study_file, barcodes_study_file, opts={})
    begin
      start_time = Time.now
      # localize files
      Rails.logger.info "#{Time.now}: Parsing 10X CellRanger source data files for #{study.name}"
      study.make_data_dir
      Rails.logger.info "#{Time.now}: Localizing output files & creating study file entries from 10X CellRanger source data for #{study.name}"

      # localize files if necessary, otherwise open newly uploaded files. check to make sure a local copy doesn't already exists
      # as we may be uploading files piecemeal from upload wizard
      # Note: matrix files must always be pulled from the bucket to ensure that we get a plain-text version due to race
      # conditions during the upload process.  It is possible to have a local copy that is waiting to be cleaned up that has
      # been gzipped, and nmatrix cannot open compressed files.  Due to the relatively small size of MEX files, the download
      # is cheap and fast.  In test mode, we are running an integration test and we know the file is local, so use that.
      if Rails.env == 'test'
        matrix_file = File.open(matrix_study_file.upload.path, 'rb')
      else
        matrix_file = Study.firecloud_client.execute_gcloud_method(:download_workspace_file, study.firecloud_project,
                                                                   study.firecloud_workspace, matrix_study_file.bucket_location,
                                                                   study.data_store_path, verify: :none)
      end

      if File.exists?(genes_study_file.upload.path)
        genes_content_type = genes_study_file.determine_content_type
        if genes_content_type == 'application/gzip'
          Rails.logger.info "#{Time.now}: Parsing #{genes_study_file.name}:#{genes_study_file.id} as application/gzip"
          genes_file = Zlib::GzipReader.open(genes_study_file.upload.path)
        else
          Rails.logger.info "#{Time.now}: Parsing #{genes_study_file.name}:#{genes_study_file.id} as text/plain"
          genes_file = File.open(genes_study_file.upload.path, 'rb')
        end
      else
        genes_file = Study.firecloud_client.execute_gcloud_method(:download_workspace_file, study.firecloud_project,
                                                                  study.firecloud_workspace, genes_study_file.bucket_location,
                                                                  study.data_store_path, verify: :none)
      end
      if File.exists?(barcodes_study_file.upload.path)
        barcodes_content_type = barcodes_study_file.determine_content_type
        if barcodes_content_type == 'application/gzip'
          Rails.logger.info "#{Time.now}: Parsing #{barcodes_study_file.name}:#{barcodes_study_file.id} as application/gzip"
          barcodes_file = Zlib::GzipReader.open(barcodes_study_file.upload.path)
        else
          Rails.logger.info "#{Time.now}: Parsing #{barcodes_study_file.name}:#{barcodes_study_file.id} as text/plain"
          barcodes_file = File.open(barcodes_study_file.upload.path, 'rb')
        end
      else
        barcodes_file = Study.firecloud_client.execute_gcloud_method(:download_workspace_file, study.firecloud_project,
                                                                     study.firecloud_workspace, barcodes_study_file.bucket_location,
                                                                     study.data_store_path, verify: :none)
      end


      # next, check if this is a re-parse job, in which case we need to remove all existing entries first
      if opts[:reparse]
        Gene.where(study_id: study.id, study_file_id: matrix_study_file.id).delete_all
        DataArray.where(study_id: study.id, study_file_id: matrix_study_file.id).delete_all
        matrix_study_file.invalidate_cache_by_file_type
      end

      # open files and read contents
      Rails.logger.info "#{Time.now}: Reading gene/barcode/matrix file contents for #{study.name}"
      matrix = NMatrix::IO::Market.load(matrix_file.path)

      # process the genes file to concatenate gene names and IDs together (for differentiating entries with duplicate names)
      raw_genes = genes_file.readlines.map(&:strip)
      genes = []
      raw_genes.each do |row|
        gene_id, gene_name = row.split.map(&:strip)
        genes << "#{gene_name} (#{gene_id})"
      end

      barcodes = barcodes_file.readlines.map(&:strip)
      matrix_file.close
      genes_file.close
      barcodes_file.close

      # validate that barcodes list does not have any repeated values
      existing_cells = study.all_expression_matrix_cells
      uniques = barcodes - existing_cells

      unless uniques.size == barcodes.size
        repeats = barcodes - uniques
        raise StandardError, "You have re-used the following cell names that were found in another expression matrix in your study (cell names must be unique across all expression matrices): #{repeats.join(', ')}"
      end

      # load significant data & construct objects
      significant_scores = matrix.to_hash
      matrix = nil # unload matrix to reduce memory load
      @genes = []
      @data_arrays = []
      @count = 0
      @child_count = 0

      Rails.logger.info "#{Time.now}: Creating new gene & data_array records from 10X CellRanger source data for #{study.name}"

      significant_scores.each do |gene_index, barcode_obj|
        gene_name = genes[gene_index]
        new_gene = Gene.new(study_id: study.id, name: gene_name, searchable_name: gene_name.downcase, study_file_id: matrix_study_file.id)
        @genes << new_gene.attributes
        gene_barcodes = []
        gene_exp_values = []
        barcode_obj.each do |barcode_index, expression_value|
          gene_barcodes << barcodes[barcode_index]
          gene_exp_values << expression_value
        end

        gene_barcodes.each_slice(DataArray::MAX_ENTRIES).with_index do |slice, index|
          cell_array = DataArray.new(name: new_gene.cell_key, cluster_name: matrix_study_file.name, array_type: 'cells',
                                     array_index: index + 1, study_file_id: matrix_study_file.id, values: slice,
                                     linear_data_type: 'Gene', linear_data_id: new_gene.id, study_id: study.id)
          @data_arrays << cell_array.attributes
        end

        gene_exp_values.each_slice(DataArray::MAX_ENTRIES).with_index do |slice, index|
          score_array = DataArray.new(name: new_gene.score_key, cluster_name: matrix_study_file.name, array_type: 'expression',
                                      array_index: index + 1, study_file_id: matrix_study_file.id, values: slice,
                                      linear_data_type: 'Gene', linear_data_id: new_gene.id, study_id: study.id)
          @data_arrays << score_array.attributes
        end

        # batch insert records in groups of 1000
        if @genes.size % 1000 == 0
          Gene.create!(@genes)
          @count += @genes.size
          Rails.logger.info "#{Time.now}: Processed #{@count} expressed genes from 10X CellRanger source data for #{study.name}"
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
      @count += @genes.size
      Rails.logger.info "#{Time.now}: Processed #{@count} expressed genes from 10X CellRanger source data for #{study.name}"
      DataArray.create(@data_arrays)
      @child_count += @data_arrays.size
      Rails.logger.info "#{Time.now}: Processed #{@child_count} child data arrays from 10X CellRanger source data for #{study.name}"
      barcodes.each_slice(DataArray::MAX_ENTRIES).with_index do |slice, index|
        known_cells = study.data_arrays.build(name: "#{matrix_study_file.name} Cells", cluster_name: matrix_study_file.name,
                                              array_type: 'cells', array_index: index + 1, values: slice,
                                              study_file_id: matrix_study_file.id, study_id: study.id)
        known_cells.save
      end

      # now we have to create empty gene records for all the non-significant genes
      # reset the count as we'll get an accurate total count from the length of the genes list
      @count = 0
      other_genes = []
      other_genes_count = 0
      genes.each do |gene|
        other_genes << Gene.new(study_id: study.id, name: gene, searchable_name: gene.downcase, study_file_id: matrix_study_file.id).attributes
        other_genes_count += 1
        if other_genes.size % 1000 == 0
          Rails.logger.info "#{Time.now}: creating #{other_genes_count} non-expressed gene records in #{study.name}"
          Gene.create(other_genes)
          @count += other_genes.size
          other_genes = []
        end
      end
      # process last batch
      Rails.logger.info "#{Time.now}: creating #{other_genes_count} non-expressed gene records in #{study.name}"
      Gene.create(other_genes)
      @count += other_genes.size

      # finish up
      matrix_study_file.update(parse_status: 'parsed')
      genes_study_file.update(parse_status: 'parsed')
      barcodes_study_file.update(parse_status: 'parsed')

      # set gene count
      study.set_gene_count

      # set the default expression label if the user supplied one
      if !study.has_expression_label? && !matrix_study_file.y_axis_label.blank?
        Rails.logger.info "#{Time.now}: Setting default expression label in #{study.name} to '#{matrix_study_file.y_axis_label}'"
        opts = study.default_options
        study.update!(default_options: opts.merge(expression_label: matrix_study_file.y_axis_label))
      end

      # set initialized to true if possible
      if study.cluster_groups.any? && study.cell_metadata.any? && !study.initialized?
        Rails.logger.info "#{Time.now}: initializing #{study.name}"
        study.update!(initialized: true)
        Rails.logger.info "#{Time.now}: #{study.name} successfully initialized"
      end

      end_time = Time.now
      time = (end_time - start_time).divmod 60.0
      @message = []
      @message << "#{Time.now}: #{study.name} 10X CellRanger expression data parse completed!"
      @message << "Gene-level entries created: #{@count}"
      @message << "Total Time: #{time.first} minutes, #{time.last} seconds"
      Rails.logger.info @message.join("\n")
      begin
        SingleCellMailer.notify_user_parse_complete(user.email, "10X CellRanger expression data has completed parsing", @message).deliver_now
      rescue => e
        Rails.logger.error "#{Time.now}: Unable to deliver email: #{e.message}"
      end

      unless opts[:skip_upload] == true
        [matrix_study_file, genes_study_file, barcodes_study_file].each do |study_file|
          Rails.logger.info "#{Time.now}: determining upload status of #{study_file.file_type}: #{study_file.upload_file_name}:#{study_file.id}"
          # now that parsing is complete, we can move file into storage bucket and delete local (unless we downloaded from FireCloud to begin with)
          # rather than relying on opts[:local], actually check if the file is already in the GCS bucket
          destination = study_file.remote_location.blank? ? study_file.upload_file_name : study_file.remote_location
          remote = Study.firecloud_client.get_workspace_file(study.firecloud_project, study.firecloud_workspace, destination)
          if remote.nil?
            begin
              Rails.logger.info "#{Time.now}: preparing to upload expression file: #{study_file.upload_file_name}:#{study_file.id} to FireCloud"
              study.send_to_firecloud(study_file)
            rescue => e
              Rails.logger.info "#{Time.now}: Expression file: #{study_file.upload_file_name}:#{study_file.id} failed to upload to FireCloud due to #{e.message}"
              SingleCellMailer.notify_admin_upload_fail(study_file, e.message).deliver_now
            end
          else
            # we have the file in FireCloud already, so just delete it
            begin
              Rails.logger.info "#{Time.now}: found remote version of #{study_file.upload_file_name}: #{remote.name} (#{remote.generation})"
              run_at = 15.seconds.from_now
              Delayed::Job.enqueue(UploadCleanupJob.new(study, study_file), run_at: run_at)
              Rails.logger.info "#{Time.now}: cleanup job for #{study_file.upload_file_name}:#{study_file.id} scheduled for #{run_at}"
            rescue => e
              # we don't really care if the delete fails, we can always manually remove it later as the file is in FireCloud already
              Rails.logger.error "#{Time.now}: Could not delete #{study_file.name}:#{study_file.id} in study #{self.name}; aborting"
              SingleCellMailer.admin_notification('Local file deletion failed', nil, "The file at #{Rails.root.join(study.data_store_path, study_file.download_location)} failed to clean up after parsing, please remove.").deliver_now
            end
          end
        end
      end
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
      SingleCellMailer.notify_user_parse_fail(user.email, "10X CellRanger expression data in #{study.name} parse has failed", error_message).deliver_now
    end
  end
end