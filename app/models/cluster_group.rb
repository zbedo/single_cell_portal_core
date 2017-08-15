class ClusterGroup
  include Mongoid::Document

  field :name, type: String
  field :cluster_type, type: String
  field :cell_annotations, type: Array
  field :domain_ranges, type: Hash

  validates_uniqueness_of :name, scope: :study_id
  validates_presence_of :name, :cluster_type

  belongs_to :study
  belongs_to :study_file

  #user annotations are created for a cluster group. search for them
  has_many :user_annotations do
    def by_name_and_user(name, user_id)
      where(name: name, user_id: user_id).first
    end
  end

  has_many :data_arrays do
    def by_name_and_type(name, type, subsample_threshold=nil)
      where(name: name, array_type: type, subsample_threshold: subsample_threshold).order_by(&:array_index).to_a
    end
  end

  index({ name: 1, study_id: 1 }, { unique: true })
  index({ study_id: 1 }, { unique: false })
  index({ study_id: 1, study_file_id: 1}, { unique: false })

  # fixed values to subsample at
  SUBSAMPLE_THRESHOLDS = [1000, 10000, 20000].freeze

  # method to return a single data array of values for a given data array name, annotation name, and annotation value
  # gathers all matching data arrays and orders by index, then concatenates into single array
  # can also load subsample arrays by supplying optional subsample_threshold
  def concatenate_data_arrays(array_name, array_type, subsample_threshold=nil, subsample_annotation=nil)
    if subsample_threshold.nil?
      data_arrays = self.data_arrays.by_name_and_type(array_name, array_type)
      all_values = []
      data_arrays.each do |array|
        all_values += array.values
      end
      return all_values
    else
      data_array = self.data_arrays.find_by(name: array_name, array_type: array_type,
                                          subsample_threshold: subsample_threshold,
                                          subsample_annotation: subsample_annotation)
      if data_array.nil?
        return []
      else
        return data_array.values
      end
    end
  end

  # return number of points in cluster_group, use x axis as all cluster_groups must have either x or y
  def points
    self.concatenate_data_arrays('x', 'coordinates').count
  end

  def is_3d?
    self.cluster_type == '3d'
  end

  # check if user has defined a range for this cluster_group (provided in study file)
  def has_range?
    !self.domain_ranges.nil?
  end

  # method used during parsing to generate representative sub-sampled data_arrays for rendering
  #
  # annotation_name: name of annotation to subsample off of
  # annotation_type: group/numeric
  # annotation_scope: cluster or study - determines where to pull metadata from to key groups off of
  def generate_subsample_arrays(sample_size, annotation_name, annotation_type, annotation_scope)
    Rails.logger.info "#{Time.now}: Generating subsample data_array for cluster '#{self.name}' using annotation: #{annotation_name} (#{annotation_type}, #{annotation_scope}) at resolution #{sample_size}"
    @cells = self.concatenate_data_arrays('text', 'cells')
    case annotation_scope
      when 'cluster'
        @annotations = self.concatenate_data_arrays(annotation_name, 'annotations')
        @annotation_key = Hash[@cells.zip(@annotations)]
      when 'study'
        # in addition to array of annotation values, we need a key to preserve the associations once we sort
        # the annotations by value
        all_annots = self.study.study_metadata_values(annotation_name, annotation_type)
        @annotation_key = {}
        @annotations = []
        @cells.each do |cell|
          @annotations << all_annots[cell]
          @annotation_key[cell] = all_annots[cell]
        end
    end

    # create a container to store subsets of arrays
    @data_by_group = {}
    # determine how many groups we have; if annotations are continuous scores, divide into 20 temporary groups
    groups = annotation_type == 'group' ? @annotations.uniq : 1.upto(20).map {|i| "group_#{i}"}
    groups.each do |group|
      @data_by_group[group] = {
          x: [],
          y: [],
          text: []
      }
      if self.is_3d?
        @data_by_group[group][:z] = []
      end
      if annotation_scope == 'cluster'
        @data_by_group[group][annotation_name.to_sym] = []
      end
    end
    raw_data = {
        text: @cells,
        x: self.concatenate_data_arrays('x', 'coordinates'),
        y: self.concatenate_data_arrays('y', 'coordinates'),
    }
    if self.is_3d?
      raw_data[:z] = self.concatenate_data_arrays('z', 'coordinates')
    end

    # divide up groups by labels (either categorical or sorted by continuous score and sliced)
    case annotation_type
      when 'group'
        @annotations.each_with_index do |annot, index|
          raw_data.each_key do |axis|
            @data_by_group[annot][axis] << raw_data[axis][index]
          end
          # we only need subsampled annotations if this is a cluster-level annotation
          if annotation_scope == 'cluster'
            @data_by_group[annot][annotation_name.to_sym] << annot
          end
        end
      when 'numeric'
        slice_size = @cells.size / groups.size
        # create a sorted array of arrays using the annotation value as the sort metric
        # first value in each sub-array is the cell name, last value is the corresponding annotation value
        sorted_annotations = @annotation_key.sort_by(&:last)
        groups.each do |group|
          sub_population = sorted_annotations.slice!(0..slice_size - 1)
          sub_population.each do |cell, annot|
            # determine where in the original source data current value resides
            original_index = @cells.index(cell)
            # store values by original_index
            raw_data.each_key do |axis|
              @data_by_group[group][axis] << raw_data[axis][original_index]
            end
            # we only need subsampled annotations if this is a cluster-level annotation
            if annotation_scope == 'cluster'
              @data_by_group[group][annotation_name.to_sym] << annot
            end
          end
        end
        # add leftovers to last group
        if sorted_annotations.size > 0
          sorted_annotations.each do |cell, annot|
            # determine where in the original source data current value resides
            original_index = @cells.index(cell)
            # store values by original_index
            raw_data.each_key do |axis|
              @data_by_group[groups.last][axis] << raw_data[axis][original_index]
            end
            # we only need subsampled annotations if this is a cluster-level annotation
            if annotation_scope == 'cluster'
              @data_by_group[groups.last][annotation_name.to_sym] << annot
            end
          end
        end
    end
    Rails.logger.info "#{Time.now}: Data assembled, now subsampling for cluster '#{self.name}' using annotation: #{annotation_name} (#{annotation_type}, #{annotation_scope}) at resolution #{sample_size}"

    # determine number of entries per group required
    @num_per_group = sample_size / groups.size

    # sort groups by size
    group_order = @data_by_group.sort_by {|k,v| v[:x].size}.map(&:first)

    # build data_array objects
    data_arrays = []
    # string key that identifies how these data_arrays were assembled, will be used to query database
    # value is identical to the annotation URL query parameter when rendering clusters
    subsample_annotation = "#{annotation_name}--#{annotation_type}--#{annotation_scope}"
    raw_data.each_key do |axis|
      case axis.to_s
        when 'text'
          @array_type = 'cells'
        when annotation_name
          @array_type = 'annotations'
        else
          @array_type = 'coordinates'
      end
      data_array = self.data_arrays.build(name: axis.to_s,
                                          array_type: @array_type,
                                          cluster_name: self.name,
                                          array_index: 1,
                                          subsample_threshold: sample_size,
                                          subsample_annotation: subsample_annotation,
                                          study_file_id: self.study_file_id,
                                          study_id: self.study_id,
                                          values: []
      )
      data_arrays << data_array
    end

    # special case for cluster-based annotations
    if annotation_scope == 'cluster'
      data_array = self.data_arrays.build(name: annotation_name,
                                          array_type: 'annotations',
                                          cluster_name: self.name,
                                          array_index: 1,
                                          subsample_threshold: sample_size,
                                          subsample_annotation: subsample_annotation,
                                          study_file_id: self.study_file_id,
                                          study_id: self.study_id,
                                          values: []
      )
      data_arrays << data_array
    end

    @cells_left = sample_size

    # iterate through groups, taking requested num_per_group and recalculating as necessary
    group_order.each_with_index do |group, index|
      data = @data_by_group[group]
      # take remaining cells if last batch, otherwise take num_per_group
      requested_sample = index == group_order.size - 1 ? @cells_left : @num_per_group
      data.each do |axis, values|
        array = data_arrays.find {|a| a.name == axis.to_s}
        sample = values.shuffle(random: Random.new(1)).take(requested_sample)
        array.values += sample
      end
      # determine how many were taken in sampling pass, will either be size of requested sample
      # or all values if requested_sample is larger than size of total values for group
      cells_taken = data[:x].size > requested_sample ? requested_sample : data[:x].size
      @cells_left -= cells_taken
      # were done with this 'group', so remove from master list
      groups.delete(group)
      # recalculate num_per_group, unless last time
      unless index == group_order.size - 1
        @num_per_group = @cells_left / groups.size
      end
    end
    data_arrays.each do |array|
      array.save
    end
    Rails.logger.info "#{Time.now}: Subsampling complete for cluster '#{self.name}' using annotation: #{annotation_name} (#{annotation_type}, #{annotation_scope}) at resolution #{sample_size}"
    true
  end
end