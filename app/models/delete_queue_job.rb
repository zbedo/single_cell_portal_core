class DeleteQueueJob < Struct.new(:object)

  ###
  #
  # DeleteQueueJob: generic class to queue objects for deletion.  Can handle studies, study files, user annotations,
  # and lists of files in a GCP bucket.
  #
  ###

  def perform
    # determine type of delete job
    case object.class.name
    when 'Study'
      # mark for deletion, rename study to free up old name for use, and restrict access by removing owner
      new_name = "DELETE-#{object.data_dir}"
      object.update!(public: false, name: new_name, url_safe_name: new_name)
    when 'StudyFile'
      file_type = object.file_type
      study = object.study

      # now remove all child objects first to free them up to be re-used.
      case file_type
      when 'Cluster'
        # first check if default cluster needs to be cleared, unless parsing has failed and cleanup didn't happen
        unless object.cluster_groups.empty? || object.parse_status == 'unparsed'
          if study.default_cluster.name == object.cluster_groups.first.name
            study.default_options[:cluster] = nil
            study.default_options[:annotation] = nil
            study.save
          end

          cluster_group_id = ClusterGroup.find_by(study_file_id: object.id, study_id: study.id).id
          delete_parsed_data(object.id, study.id, ClusterGroup)
          delete_parsed_data(object.id, study.id, DataArray)
          user_annotations = UserAnnotation.where(study_id: study.id, cluster_group_id: cluster_group_id )
          user_annotations.each do |annot|
            annot.user_data_arrays.delete_all
            annot.user_annotation_shares.delete_all
          end
          user_annotations.delete_all
        end
      when 'Coordinate Labels'
        delete_parsed_data(object.id, study.id, DataArray)
        remove_file_from_bundle
      when 'Expression Matrix'
        delete_parsed_data(object.id, study.id, Gene, DataArray)
        study.set_gene_count
      when 'MM Coordinate Matrix'
        delete_parsed_data(object.id, study.id, Gene, DataArray)
        study.set_gene_count
      when /10X/
        object.study_file_bundle.study_files.each do |file|
          file.update(parse_status: 'unparsed')
        end
        parent = object.study_file_bundle.parent
        delete_parsed_data(parent.id, study.id, Gene, DataArray)
        remove_file_from_bundle
      when 'Metadata'
        delete_parsed_data(object.id, study.id, CellMetadatum, DataArray)
        study.update(cell_count: 0)
      when 'Gene List'
        delete_parsed_data(object.id, study.id, PrecomputedScore)
      when 'BAM Index'
        remove_file_from_bundle
      else
        nil
      end

      # if this is a parent bundled file, delete all other associated files and bundle
      if object.is_bundle_parent?
        object.bundled_files.each do |file|
          Rails.logger.info "Deleting bundled file #{file.upload_file_name} from #{study.name} due to parent deletion: #{object.upload_file_name}"
          DeleteQueueJob.new(file).delay.perform
        end
        remove_file_from_bundle
      end

      # queue study file object for deletion, set file_type to DELETE to prevent it from being picked up in any queries
      new_name = "DELETE-#{SecureRandom.uuid}"
      object.update!(queued_for_deletion: true, upload_file_name: new_name, name: new_name, file_type: 'DELETE')

      # reset initialized if needed
      if study.cluster_groups.empty? || study.genes.empty? || study.cell_metadata.empty?
        study.update!(initialized: false)
      end
    when 'UserAnnotation'
      # set queued for deletion to true and set user annotation name
      new_name = "DELETE-#{SecureRandom.uuid}"
      object.update!(name: new_name)

      # delete data arrays and shares right away
      object.user_data_arrays.delete_all
      object.user_annotation_shares.delete_all
    when 'Google::Cloud::Storage::File::List'
      # called when a user wants to delete an entire directory of files from a FireCloud submission
      # this is run in the foreground as Delayed::Job cannot deserialize the list anymore
      files = object
      files.each {|f| f.delete}
      while files.next?
        files = object.next
        files.each {|f| f.delete}
      end
    end
  end

  private

  # remove a study_file from a study_file_bundle, and clean up as necessary
  def remove_file_from_bundle
    bundle = object.study_file_bundle
    bundle.original_file_list.delete_if {|file| file['file_type'] == object.file_type} # this edits the list in place, but is not saved
    object.update(study_file_bundle_id: nil)
    bundle.save
    if bundle.original_file_list.empty?
      bundle.destroy
    end
  end

  # removed all parsed data from provided list of models
  def delete_parsed_data(object_id, study_id, *models)
    models.each do |model|
      model.where(study_file_id: object_id, study_id: study_id).delete_all
    end
  end
end