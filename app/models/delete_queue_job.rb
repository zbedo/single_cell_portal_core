class DeleteQueueJob < Struct.new(:object)
  # generic class to queue objects for deletion.  Can handle studies & study files

  def perform
    # determine type of delete job
    case object.class.name
      when 'Study'
        # mark for deletion, rename study to free up old name for use, and restrict access by removing owner
        new_name = "DELETE-#{object.data_dir}"
        object.update!(public: false, user_id: nil, name: new_name, url_safe_name: new_name)
      when 'StudyFile'
        file_type = object.file_type
        study = object.study

        # reset initialized if needed
        if study.cluster_ordinations_files.empty? || study.expression_matrix_files.empty? || study.metadata_file.nil?
          study.update!(initialized: false)
        end

        # now remove all child objects first to free them up to be re-used.
        case file_type
          when 'Cluster'
            # first check if default cluster needs to be cleared
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
          when 'Expression Matrix'
            ExpressionScore.where(study_file_id: object.id, study_id: study.id).delete_all
            DataArray.where(study_file_id: object.id, study_id: study.id).delete_all
            study.set_gene_count
          when 'Metadata'
            StudyMetadatum.where(study_file_id: object.id, study_id: study.id).delete_all
            study.update(cell_count: 0)
          when 'Gene List'
            PrecomputedScore.where(study_file_id: object.id, study_id: study.id).delete_all
          else
            nil
        end

        # queue study file object for deletion
        new_name = "DELETE-#{SecureRandom.uuid}"
        object.update!(queued_for_deletion: true, upload_file_name: new_name, name: new_name, file_type: nil)
      when 'UserAnnotation'
        # set queued for deletion to true and set user annotation name
        new_name = "DELETE-#{SecureRandom.uuid}"
        object.update!(name: new_name)

        # delete data arrays and shares right away
        object.user_data_arrays.delete_all
        object.user_annotation_shares.delete_all
    end
  end
end