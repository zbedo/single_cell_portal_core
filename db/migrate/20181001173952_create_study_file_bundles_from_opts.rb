class CreateStudyFileBundlesFromOpts < Mongoid::Migration
  def self.up
    StudyFile.where(:file_type.in => StudyFileBundle::BUNDLE_TYPES).each do |study_file|
      unless study_file.study_file_bundle.present?
        if study_file.bundled_files.any?
          bundle_payload = [
              {
                  'name' => study_file.upload_file_name,
                  'file_type' => study_file.file_type
              }
          ]
          study_file.bundled_files.each do |file|
            bundle_payload << {
                'name' => file.upload_file_name,
                'file_type' => file.file_type
            }
          end
          StudyFileBundle.create!(study_id: study_file.study_id, original_file_list: bundle_payload,
                                  bundle_type: study_file.file_type)
        end
      end
    end
  end

  def self.down
    StudyFileBundle.each do |bundle|
      bundle.bundled_files.each do |study_file|
        case study_file.file_type
        when /10X/
          study_file.options.merge!({matrix_id: bundle.parent.id.to_s})
        when 'BAM Index'
          study_file.options.merge!({bam_id: bundle.parent.id.to_s})
        when 'Coordinate Labels'
          study_file.options.merge!({cluster_group_id: bundle.bundle_target.id.to_s})
        end
        study_file.study_file_bundle_id = nil
        study_file.save
      end
      bundle.parent.update(study_file_bundle_id: nil)
    end
    StudyFileBundle.delete_all
  end
end