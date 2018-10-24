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

          clusters = ClusterGroup.where(study_file_id: object.id, study_id: study.id)
          cluster_group_id = clusters.first.id
          clusters.delete_all
          DataArray.where(study_file_id: object.id, study_id: study.id).delete_all
          user_annotations = UserAnnotation.where(study_id: study.id, cluster_group_id: cluster_group_id )
          user_annotations.each do |annot|
            annot.user_data_arrays.delete_all
            annot.user_annotation_shares.delete_all
          end
          user_annotations.delete_all
        end
      when 'Coordinate Labels'
        DataArray.where(study_file_id: object.id, study_id: study.id).delete_all
      when 'Expression Matrix'
        Gene.where(study_file_id: object.id, study_id: study.id).delete_all
        DataArray.where(study_file_id: object.id, study_id: study.id).delete_all
        study.set_gene_count
      when 'MM Coordinate Matrix'
        Gene.where(study_file_id: object.id, study_id: study.id).delete_all
        DataArray.where(study_file_id: object.id, study_id: study.id).delete_all
        study.set_gene_count
      when 'Metadata'
        CellMetadatum.where(study_file_id: object.id, study_id: study.id).delete_all
        DataArray.where(study_file_id: object.id, study_id: study.id).delete_all
        study.update(cell_count: 0)
      when 'Gene List'
        PrecomputedScore.where(study_file_id: object.id, study_id: study.id).delete_all
      when /(10X|Index|Coordinate)/ # this is a bundled 10X file, a BAM Index, or a Coordinate Label
        bundle = object.study_file_bundle
        bundle.original_file_list.delete_if {|file| file['file_type'] == object.file_type} # this edits the list in place, but is not saved
        object.update(study_file_bundle_id: nil)
        bundle.save
        if bundle.original_file_list.empty?
          bundle.destroy
        end
      else
        nil
      end

      # if this is a parent bundled file, delete all other associated files and bundle
      if object.is_bundle_parent?
        object.bundled_files.each do |file|
          Rails.logger.info "Deleting bundled file #{file.upload_file_name} from #{study.name} due to parent deletion: #{object.upload_file_name}"
          DeleteQueueJob.new(file).delay.perform
        end
        bundle = object.study_file_bundle
        bundle.original_file_list.delete_if {|file| file['file_type'] == object.file_type} # this edits the list in place, but is not saved
        object.update(study_file_bundle_id: nil)
        bundle.save
        if bundle.original_file_list.empty?
          bundle.destroy
        end
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
end