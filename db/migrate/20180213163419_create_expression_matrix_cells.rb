class CreateExpressionMatrixCells < Mongoid::Migration
  def self.up
    Study.all.each do |study|
      expression_files = study.expression_matrix_files
      if expression_files.count == 0
        Rails.logger.info "#{Time.zone.now} skipping #{study.name}, no expression data"
      elsif expression_files.count == 1
        cell_array = study.all_cells_array
        if cell_array.empty?
          cell_array = study.all_cells
        end
        if cell_array.size > 0
          Rails.logger.info "#{Time.zone.now} processing #{study.name} with 1 expression file (using all_cells arrays)"
          expression_file = study.expression_matrix_files.first
          cell_array.each_slice(DataArray::MAX_ENTRIES).with_index do |slice, index|
            Rails.logger.info "#{Time.zone.now}: Create known cells array ##{index + 1} for #{expression_file.name}:#{expression_file.id} in #{study.name}"
            known_cells = study.data_arrays.build(name: "#{expression_file.name} Cells", cluster_name: expression_file.name,
                                                  array_type: 'cells', array_index: index + 1, values: slice,
                                                  study_file_id: expression_file.id, study_id: study.id)
            known_cells.save
          end
        else
          Rails.logger.info "#{Time.zone.now} processing #{study.name} with #{expression_files.count} files (in background)"
          expression_files.each do |file|
            file.delay.generate_expression_matrix_cells
          end
        end
      else
        Rails.logger.info "#{Time.zone.now} processing #{study.name} with #{expression_files.count} files (in background)"
        expression_files.each do |file|
          file.delay.generate_expression_matrix_cells
        end
      end
    end
  end

  def self.down
    Study.all.each do |study|
      exp_file_ids = study.expression_matrix_files.map(&:id)
      DataArray.where(study_id: study.id, linear_data_type: 'Study', linear_data_id: study.id, :study_file_id.in => exp_file_ids).delete_all
    end
  end
end