class ResetDefaultAnnotations < Mongoid::Migration
  def self.up
    Study.all.each do |study|
      if study.default_annotation.present?
        current_annotation = study.default_annotation
        annotation_name, annotation_type, annotation_scope = current_annotation.split('--')
        can_visualize = true
        if annotation_type == 'group' # numeric annotations are fine, so skip
          case annotation_scope
          when 'study'
            annotation = study.cell_metadata.by_name_and_type(annotation_name, annotation_type)
            can_visualize = annotation.can_visualize?
          when 'cluster'
            cluster = study.default_cluster
            annotation = cluster.cell_annotations.detect {|annot| annot[:name] == annotation_name}
            can_visualize = cluster.can_visualize_cell_annotation?(annotation)
          end
          # if we have a bad annotation, reset to the first available cell metadata annotation
          # that can visualize.  if nothing else is available, leave as-is
          if !can_visualize
            study.cell_metadata.each do |metadata|
              if metadata.can_visualize?
                study.default_options[:annotation] = metadata.annotation_select_value
                study.default_options[:old_annotation] = current_annotation # only for reversibility
                study.save
                break
              end
            end
          end
        end
      end
    end
  end

  def self.down
    Study.all.each do |study|
      old_default_annotation = study.default_options[:old_annotation]
      if old_default_annotation.present?
        study.default_options[:annotation] = old_default_annotation
        study.save
      end
    end
  end
end
