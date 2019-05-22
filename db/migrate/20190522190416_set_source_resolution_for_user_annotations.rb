class SetSourceResolutionForUserAnnotations < Mongoid::Migration
  def self.up
    UserAnnotation.each do |annot|
      resolution = annot.subsampled_at
      if resolution == 'All Cells'
        annot.update(source_resolution: nil)
      else
        annot.update(source_resolution: resolution.to_i)
      end
    end
  end

  def self.down
    UserAnnotation.all.each {|annot| annot.unset(:source_resolution)}
  end
end