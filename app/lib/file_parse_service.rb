# collection of methods involved in parsing files
class FileParseService
  def self.run_parse_job(study_file, study, user)
    logger = Rails.logger

    logger.info "#{Time.zone.now}: Parsing #{study_file.name} as #{study_file.file_type} in study #{study.name}"
    case study_file.file_type
    when 'Cluster'
      study_file.update(parse_status: 'parsing')
      job = IngestJob.new(study: study, study_file: study_file, user: user, action: :ingest_cluster)
      job.delay.push_remote_and_launch_ingest
    when 'Coordinate Labels'
      study_file.update(parse_status: 'parsing')
      # we need to create the bundle here as it doesn't exist yet
      parent_cluster_file = ClusterGroup.find_by(id: study_file.options[:cluster_group_id]).study_file
      file_list = StudyFileBundle.generate_file_list(parent_cluster_file, study_file)
      StudyFileBundle.create(study_id: study.id, bundle_type: parent_cluster_file.file_type, original_file_list: file_list)
      study.delay.initialize_coordinate_label_data_arrays(study_file, user)
    when 'Expression Matrix'
      study_file.update(parse_status: 'parsing')
      study.delay.initialize_gene_expression_data(study_file, user)
    when 'MM Coordinate Matrix'
      study.send_to_firecloud(study_file)
      bundle = study_file.study_file_bundle
      barcodes = study_file.bundled_files.detect {|f| f.file_type == '10X Barcodes File'}
      genes = study_file.bundled_files.detect {|f| f.file_type == '10X Genes File'}
      if barcodes.present? && genes.present? && bundle.completed?
        study_file.update(parse_status: 'parsing')
        genes.update(parse_status: 'parsing')
        barcodes.update(parse_status: 'parsing')
        ParseUtils.delay.cell_ranger_expression_parse(study, user, study_file, genes, barcodes)
      else
        logger.info "#{Time.zone.now}: Parse for #{study_file.name} as #{study_file.file_type} in study #{study.name} aborted; missing required files"
      end
    when '10X Genes File'
      study.send_to_firecloud(study_file)
      bundle = study_file.study_file_bundle
      matrix = bundle.parent
      barcodes = bundle.bundled_files.detect {|f| f.file_type == '10X Barcodes File' }
      if barcodes.present? && matrix.present? && bundle.completed?
        study_file.update(parse_status: 'parsing')
        matrix.update(parse_status: 'parsing')
        barcodes.update(parse_status: 'parsing')
        ParseUtils.delay.cell_ranger_expression_parse(study, user, matrix, study_file, barcodes)
      else
        # we can only get here if we have a matrix and no barcodes, which means the barcodes form is already rendered
        logger.info "#{Time.zone.now}: Parse for #{study_file.name} as #{study_file.file_type} in study #{study.name} aborted; missing required files"
        study.delay.send_to_firecloud(study_file)
      end
    when '10X Barcodes File'
      study.send_to_firecloud(study_file)
      bundle = study_file.study_file_bundle
      matrix = bundle.parent
      genes = bundle.bundled_files.detect {|f| f.file_type == '10X Genes File' }
      if genes.present? && matrix.present? && bundle.completed?
        study_file.update(parse_status: 'parsing')
        genes.update(parse_status: 'parsing')
        matrix.update(parse_status: 'parsing')
        ParseUtils.delay.cell_ranger_expression_parse(study, user, matrix, genes, study_file)
      else
        # we can only get here if we have a matrix and no genes, which means the genes form is already rendered
        logger.info "#{Time.zone.now}: Parse for #{study_file.name} as #{study_file.file_type} in study #{study.name} aborted; missing required files"
        study.delay.send_to_firecloud(study_file)
      end
    when 'Gene List'
      study_file.update(parse_status: 'parsing')
      study.delay.initialize_precomputed_scores(study_file, user)
    when 'Metadata'
      study_file.update(parse_status: 'parsing')
      study.send_to_firecloud(study_file)
      job = IngestJob.new(study: study, study_file: study_file, user: user, action: :ingest_cell_metadata)
      job.delay.push_remote_and_launch_ingest
    end
    changes = ["Study file added: #{study_file.upload_file_name}"]
    if study.study_shares.any?
      SingleCellMailer.share_update_notification(study, changes, user).deliver_now
    end
  end
end
