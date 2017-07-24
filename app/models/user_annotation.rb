class UserAnnotation
  include Mongoid::Document
  field :name, type: String
  field :values, type: Array

  belongs_to :user
  belongs_to :cluster_group
  belongs_to :study

  has_many :user_data_arrays do
    def by_name_and_type(name, type, subsample_threshold=nil)
      where(name: name, array_type: type, subsample_threshold: subsample_threshold).order_by(&:array_index).to_a
    end
  end

  index({ user_id: 1, study_id: 1, cluster_group_id: 1, name: 1}, { unique: true })

  validates_presence_of :name, :values
  validates_uniqueness_of :name, scope: [:user_id, :study_id, :cluster_group_id]

  #accepts_nested_attributes_for :user_data_arrays, allow_destroy: true

  def initialize_user_data_arrays(user_data_arrays_attributes, annotation, threshold, loaded_annotation)
    #Assemble hash of cell names and annotations
    logger.info("loaded annot: #{loaded_annotation}")
    cluster = self.cluster_group
    max_length = cluster.points

    case threshold
      when 1000
        extrapolate(user_data_arrays_attributes, [10000, 20000], max_length, cluster, annotation)
      when 10000
        extrapolate(user_data_arrays_attributes, [20000], max_length, cluster, annotation)
        subsample(user_data_arrays_attributes, [1000],cluster, annotation, max_length)
      when 20000
        extrapolate(user_data_arrays_attributes, [], max_length, cluster, annotation)
        subsample(user_data_arrays_attributes, [10000, 1000],cluster, annotation, max_length)
      else
        extrapolate(user_data_arrays_attributes, [], max_length, cluster, annotation)
        subsample(user_data_arrays_attributes, [20000, 10000, 1000],cluster, loaded_annotation, max_length )
    end
  end

  def concatenate_user_data_arrays(array_name, array_type, subsample_threshold=nil, subsample_annotation=nil)
    if subsample_threshold.nil?
      user_data_arrays = self.user_data_arrays.by_name_and_type(array_name, array_type)
      all_values = []
      user_data_arrays.each do |array|
        all_values += array.values
      end
      return all_values
    else
      user_data_array = self.user_data_arrays.find_by(name: array_name, array_type: array_type,
                                            subsample_threshold: subsample_threshold,
                                            subsample_annotation: subsample_annotation)
      if user_data_array.nil?
        return []
      else
        return user_data_array.values
      end
    end
  end

  def create_array(cluster, threshold, annotation, user_data_arrays_attributes)
    user_annotation_map = {}
    user_data_arrays_attributes.keys.each do |key|
      name = user_data_arrays_attributes[key][:name]
      user_data_arrays_attributes[key][:values].split(',').each do |cell_name|
        user_annotation_map[cell_name] = name
      end
    end

    cell_name_array = cluster.concatenate_data_arrays('text', 'cells', threshold, annotation)
    x_array = cluster.concatenate_data_arrays('x', 'coordinates', threshold, annotation)
    y_array = cluster.concatenate_data_arrays('y', 'coordinates', threshold, annotation)

    if !annotation.nil? and annotation.include? 'user'
      logger.info("Annotation is not nil and has user, in subsampling: #{annotation}")
      user_annot = UserAnnotation.where(name: annotation.gsub('--group--user','')).first
      cell_name_array = user_annot.concatenate_user_data_arrays('text', 'cells', threshold, annotation)
      x_array = user_annot.concatenate_user_data_arrays('x', 'coordinates', threshold, annotation)
      y_array = user_annot.concatenate_user_data_arrays('y', 'coordinates', threshold, annotation)
      logger.info("x_array: #{x_array}")
    end

    logger.info("threshold: #{threshold}")
    logger.info("annotation: #{annotation}")


    annotation_array = []
    undefined_happened = false

    cell_name_array.each do |name|
      cell_name = user_annotation_map[name]
      if cell_name.nil?
        cell_name = 'Undefined'
        undefined_happened = true
      end
      annotation_array << cell_name
    end


    #Create subsample annotation
    sub_an = self.name + '--group--user'
    x_arrays = x_array.each_slice(DataArray::MAX_ENTRIES).to_a
    y_arrays = y_array.each_slice(DataArray::MAX_ENTRIES).to_a
    cell_name_arrays = cell_name_array.each_slice(DataArray::MAX_ENTRIES).to_a


    annotation_array.each_slice(DataArray::MAX_ENTRIES).each_with_index do |val, i|
      if !threshold.nil?
        #Create annotation array
        UserDataArray.create(name: name, array_type: 'annotations', values: val, cluster_name: cluster.name, array_index: i+1, subsample_threshold: threshold, subsample_annotation: sub_an, user_id: self.user_id, cluster_group_id: self.cluster_group_id, study_id: self.study_id, user_annotation_id: id)
        logger.info('created annotation')
        #Create X
        UserDataArray.create(name: 'x', array_type: 'coordinates', values: x_arrays[i], cluster_name: cluster.name, array_index: i+1, subsample_threshold: threshold, subsample_annotation: sub_an, user_id: self.user_id, cluster_group_id: self.cluster_group_id, study_id: self.study_id, user_annotation_id: id )
        logger.info('created x')
        #Create Y
        UserDataArray.create(name: 'y', array_type: 'coordinates', values: y_arrays[i], cluster_name: cluster.name, array_index: i+1, subsample_threshold: threshold, subsample_annotation: sub_an, user_id: self.user_id, cluster_group_id: self.cluster_group_id, study_id: self.study_id, user_annotation_id: id)
        logger.info('created y')
        #Create Cell Array
        UserDataArray.create(name: 'text', array_type: 'cells', values: cell_name_arrays[i], cluster_name: cluster.name, array_index: i+1, subsample_threshold: threshold, subsample_annotation: sub_an, user_id: self.user_id, cluster_group_id: self.cluster_group_id, study_id: self.study_id, user_annotation_id: id)
        logger.info('created cells')
      else
        #Create annotation array
        UserDataArray.create(name: name, array_type: 'annotations', values: val, cluster_name: cluster.name, array_index: i+1, user_id: self.user_id, cluster_group_id: self.cluster_group_id, study_id: self.study_id, user_annotation_id: id)
        logger.info('created annotations in else')
        #Create X
        x = UserDataArray.new(name: 'x', array_type: 'coordinates', values: x_arrays[i], cluster_name: cluster.name, array_index: i+1, user_id: self.user_id, cluster_group_id: self.cluster_group_id, study_id: self.study_id, user_annotation_id: id )
        logger.info("created x in else: #{x}")
        x.save!
        #Create Y
        UserDataArray.create(name: 'y', array_type: 'coordinates', values: y_arrays[i], cluster_name: cluster.name, array_index: i+1, user_id: self.user_id, cluster_group_id: self.cluster_group_id, study_id: self.study_id, user_annotation_id: id)
        logger.info('created y in else')
        #Create Cell Array
        UserDataArray.create(name: 'text', array_type: 'cells', values: cell_name_arrays[i], cluster_name: cluster.name, array_index: i+1, user_id: self.user_id, cluster_group_id: self.cluster_group_id, study_id: self.study_id, user_annotation_id: id)
        logger.info('created cells in else')
      end
    end

    if undefined_happened
      new_values = self.values
      if !new_values.include? 'Undefined'
        new_values << 'Undefined'
        self.update(values: values)
      end
    end

  end

  def extrapolate(data, thresholds, max_length, cluster, annotation)
    full_thresh = [nil]
    thresholds.each do |th|
       if max_length > th
         full_thresh << th
       end
    end
    logger.info(full_thresh)
    full_thresh.each do |threshold|
      logger.info('extrapolating: ')
      logger.info(threshold)
      create_array(cluster, threshold, annotation, data)
    end

  end

  def subsample(data, thresholds, cluster, annotation, max_length)
    #Subsample
    logger.info('subsampling' + "#{annotation}")
    thresholds.each do |threshold|
      if threshold < max_length
        create_array(cluster, threshold, annotation, data)
      end
    end
  end

  def subsampled_at
    annotations = user_data_arrays.find_by(array_type: 'annotations').to_a

    vals = values
    created_at = ''

    max_length = 0

    annotations.each do |annot|
      length = annot.values.length
      if length > max_length
        max_length = length
      end
    end

    undefined_exists_at_10k = false
    undefined_exists_at_20k = false

    if max_length > 10000
      undefined_exists_at_10k = user_data_arrays.find_by(array_type: 'annotations', subsample_threshold: 10000).values.include? 'Undefined'
    end

    if max_length > 20000
      undefined_exists_at_20k = user_data_arrays.find_by(array_type: 'annotations', subsample_threshold: 20000).values.include? 'Undefined'
    end

    undefined_exists = vals.include? 'Undefined'

    if undefined_exists
      if max_length > 20000
        if undefined_exists_at_20k
          if undefined_exists_at_10k
            #exists at 10k and 20k, so must have been at 1k
            created_at = 'Created at a subsample of 1,000 Cells'
          else
            #exists at 20k but not 10k, so was created at 10k
            created_at = 'Created at a subsample of 10,000 Cells'
          end
        else
          #max length > 20k byt doesn't exist so:
          created_at = 'Created at a subsample of 20,000 Cells'
        end
      elsif max_length < 20000 and max_length > 10000
        if undefined_exists_at_10k
          #exists at 10k and 20k, so must have been at 1k
          created_at = 'Created at a subsample of 1,000 Cells'
        else
          #exists at 20k but not 10k, so was created at 10k
          created_at = 'Created at a subsample of 10,000 Cells'
        end
      elsif max_length < 10000 and max_length > 1000
        #max length is less than 10k. Max length > 1k. Undefined exists, so must be created at 1k.
        logger.info("Here: #{undefined_exists}")
        created_at = 'Created at a subsample of 1,000 Cells'
    end
    else
      #No undefined means the annotation was created at
      created_at = 'Created at Full Data'
    end
    created_at
  end

  def formatted_annotation_name
    self.name + '--group--user'
  end

end
