class UserAnnotation
  include Mongoid::Document
  field :name, type: String
  field :values, type: Array
  field :queued_for_deletion, type: Boolean, default: false

  belongs_to :user
  belongs_to :cluster_group
  belongs_to :study

  #user data arrays belong to user annotations
  has_many :user_data_arrays do
    def by_name_and_type(name, type, subsample_threshold=nil, subsample_annotation=nil)
      where(name: name, array_type: type, subsample_threshold: subsample_threshold, subsample_annotation: subsample_annotation).order_by(&:array_index).to_a
    end
  end

  has_many :user_annotation_shares, dependent: :delete do
    def can_edit
      where(permission: 'Edit').map(&:email)
    end

    def can_view
      all.to_a.map(&:email)
    end
  end

  accepts_nested_attributes_for :user_annotation_shares, allow_destroy: true, reject_if: proc { |attributes| attributes['email'].blank? }

  index({ user_id: 1, study_id: 1, cluster_group_id: 1, name: 1}, { unique: true })
  #must have a name and values
  validates_presence_of :name, :values
  #unique values are name per user, study and cluster
  validates_uniqueness_of :name, scope: [:user_id, :study_id, :cluster_group_id]

  # populate specific errors for user annotation shares since they share the same form
  validate do |user_annotation|
    user_annotation.user_annotation_shares.each do |user_annotation_share|
      next if user_annotation_share.valid?
      user_annotation_share.errors.full_messages.each do |msg|
        errors.add(:base, "Share Error - #{msg}")
      end
    end
  end

  #create an annotations user data arrays
  def initialize_user_data_arrays(user_data_arrays_attributes, annotation, threshold, loaded_annotation)
    #set cluster and max length of data array
    #max length is the actual length of the annotation when not subsampled
    cluster = self.cluster_group
    max_length = cluster.points

    #handle different cases when creating annotations when different subsampling levels were selected, for creating data arrays
    case threshold
      when 1000
        #when created at a level of 1000, you have to:
        #extrapolate to a level of 10k, 20k and full data
        extrapolate(user_data_arrays_attributes, [10000, 20000], max_length, cluster, annotation)
        #and create at 1k
        create_array(cluster, 1000, annotation, user_data_arrays_attributes)
      when 10000
        #when created at a level of 10k, you have to:
        #extrapolate to a level of 20k and full data
        extrapolate(user_data_arrays_attributes, [20000], max_length, cluster, annotation)
        #create at 1000
        subsample(user_data_arrays_attributes, [1000],cluster, annotation, max_length)
        #and create at 10k
        create_array(cluster, 10000, annotation, user_data_arrays_attributes)
      when 20000
        #when created at a level of 20k, you have to:
        #extrapolate to a level of full data
        extrapolate(user_data_arrays_attributes, [], max_length, cluster, annotation)
        #subsample at 10k and 1k
        subsample(user_data_arrays_attributes, [10000, 1000],cluster, annotation, max_length)
        #and create at 20k
        create_array(cluster, 20000, annotation, user_data_arrays_attributes)
      else
        #when created at full data, aka no threshold, you have to extrapolate to full data, aka create at full data, and subsample at 20k, 10k, and 1k
        extrapolate(user_data_arrays_attributes, [], max_length, cluster, annotation)
        subsample(user_data_arrays_attributes, [20000, 10000, 1000], cluster, loaded_annotation, max_length )
    end
  end

  #combine split data arrays when they were longer than 100k values each.
  def concatenate_user_data_arrays(array_name, array_type, subsample_threshold=nil, subsample_annotation=nil)
    #neccessary but uncertain why needed
    if subsample_threshold.blank?
      subsample_threshold = nil
      subsample_annotation = nil
    end
    #get all of the data arrays and combine them
      user_data_arrays = self.user_data_arrays.by_name_and_type(array_name, array_type, subsample_threshold, subsample_annotation)
      all_values = []
      user_data_arrays.each do |array|
        all_values += array.values
      end
      return all_values
  end

  #create a data array-- user data arrays attributes is from params follows form:
  # {label:{name=>'label' values=>'Cell1, Cell2...' } label2=>...}
  #cluster is current cluster
  def create_array(cluster, threshold, annotation, user_data_arrays_attributes)
    #create a hash of cell names of format
    #{cell_name1=>'its label', cell_name_2=>'its label'}
    user_annotation_map = {}
    user_data_arrays_attributes.keys.each do |key|
      name = user_data_arrays_attributes[key][:name]
      user_data_arrays_attributes[key][:values].split(',').each do |cell_name|
        user_annotation_map[cell_name] = name
      end
    end

    #get the cell names, x values and y values this selection was created on
    cell_name_array = cluster.concatenate_data_arrays('text', 'cells', threshold, annotation)
    x_array = cluster.concatenate_data_arrays('x', 'coordinates', threshold, annotation)
    y_array = cluster.concatenate_data_arrays('y', 'coordinates', threshold, annotation)

    #user data arrays are different than normal data arrays, so if you created a selection from a user selection this:
    #gets the cell names, x values and y values this selection was created on
    if !annotation.nil? and annotation.include? 'user'
      user_annot = UserAnnotation.where(name: annotation.gsub('--group--user','')).first
      cell_name_array = user_annot.concatenate_user_data_arrays('text', 'cells', threshold, annotation)
      x_array = user_annot.concatenate_user_data_arrays('x', 'coordinates', threshold, annotation)
      y_array = user_annot.concatenate_user_data_arrays('y', 'coordinates', threshold, annotation)
    end

    #get an ordered array of labels
    annotation_array = []
    #check if any of the values are undefined, aka this data array is being extrapolated
    undefined_happened = false

    cell_name_array.each do |name|
      cell_name = user_annotation_map[name]
      if cell_name.nil?
        cell_name = 'Undefined'
        undefined_happened = true
      end
      annotation_array << cell_name
    end


    #Create the name of the subsample annotation
    sub_an = self.name + '--group--user'

    #Slice the arrays if into segments smaller than the maximum size (100k)
    x_arrays = x_array.each_slice(UserDataArray::MAX_ENTRIES).to_a
    y_arrays = y_array.each_slice(UserDataArray::MAX_ENTRIES).to_a
    cell_name_arrays = cell_name_array.each_slice(UserDataArray::MAX_ENTRIES).to_a

    #create each data array
    annotation_array.each_slice(UserDataArray::MAX_ENTRIES).each_with_index do |val, i|
      #if threshold exists then the subsample annotation and threshold need to be set on the created data array
      if !threshold.nil?
        Rails.logger.info "#{Time.now}: Creating user annotation user data arrays without threshold for name: #{name}"
        #Create annotation array
        UserDataArray.create(name: name, array_type: 'annotations', values: val, cluster_name: cluster.name, array_index: i+1, subsample_threshold: threshold, subsample_annotation: sub_an, user_id: self.user_id, cluster_group_id: self.cluster_group_id, study_id: self.study_id, user_annotation_id: id)
        #Create X
        UserDataArray.create(name: 'x', array_type: 'coordinates', values: x_arrays[i], cluster_name: cluster.name, array_index: i+1, subsample_threshold: threshold, subsample_annotation: sub_an, user_id: self.user_id, cluster_group_id: self.cluster_group_id, study_id: self.study_id, user_annotation_id: id )
        #Create Y
        UserDataArray.create(name: 'y', array_type: 'coordinates', values: y_arrays[i], cluster_name: cluster.name, array_index: i+1, subsample_threshold: threshold, subsample_annotation: sub_an, user_id: self.user_id, cluster_group_id: self.cluster_group_id, study_id: self.study_id, user_annotation_id: id)
        #Create Cell Array
        UserDataArray.create(name: 'text', array_type: 'cells', values: cell_name_arrays[i], cluster_name: cluster.name, array_index: i+1, subsample_threshold: threshold, subsample_annotation: sub_an, user_id: self.user_id, cluster_group_id: self.cluster_group_id, study_id: self.study_id, user_annotation_id: id)

      #Otherwise, if no threshold or annotation, then no threshold or annotation need to be set
      else
        #Create annotation array
        Rails.logger.info "#{Time.now}: Creating user annotation user data arrays with threshold: #{threshold} for name: #{name}"
        UserDataArray.create(name: name, array_type: 'annotations', values: val, cluster_name: cluster.name, array_index: i+1, user_id: self.user_id, cluster_group_id: self.cluster_group_id, study_id: self.study_id, user_annotation_id: id)
        #Create X
        UserDataArray.create(name: 'x', array_type: 'coordinates', values: x_arrays[i], cluster_name: cluster.name, array_index: i+1, user_id: self.user_id, cluster_group_id: self.cluster_group_id, study_id: self.study_id, user_annotation_id: id )
        #Create Y
        UserDataArray.create(name: 'y', array_type: 'coordinates', values: y_arrays[i], cluster_name: cluster.name, array_index: i+1, user_id: self.user_id, cluster_group_id: self.cluster_group_id, study_id: self.study_id, user_annotation_id: id)
        #Create Cell Array
        UserDataArray.create(name: 'text', array_type: 'cells', values: cell_name_arrays[i], cluster_name: cluster.name, array_index: i+1, user_id: self.user_id, cluster_group_id: self.cluster_group_id, study_id: self.study_id, user_annotation_id: id)
      end
    end

    #If undefined happened then the annotation these data arrays belong to needs to have undefined in its values field
    if undefined_happened
      new_values = self.values
      #Make sure not to duplicate undefined, but add it to the field values
      if !new_values.include? 'Undefined'
        new_values << 'Undefined'
        self.update(values: values)
      end
    end

  end

  #If you created a selection at a lower level, and need to view it at higher levels, you must extrapolate that selection to those levels
  #Extrapolating labels cells that were labeled at the lower level the same, and cells that weren't present in the lower level as 'Undefined'
  def extrapolate(data, thresholds, max_length, cluster, annotation)
    #full_thresh is the array of thresholds that data arrays have to be created at
    #when threshold is nil, a data array at full data is created
    #therefore, full thresh has nil by default to always create data arrays at no subsampling level
    full_thresh = [nil]

    #add thresholds to be created at, as long as the threshold isn't bigger than the size of full data, because that would be impossible
    thresholds.each do |th|
       if max_length > th
         full_thresh << th
       end
    end

    #create a data array at each threshold
    full_thresh.each do |threshold|
      create_array(cluster, threshold, annotation, data)
    end

  end

  #If you created a selection at a higher level, and need to view it at lower levels, you must subsample that selection to those levels
  #Subsampling labels cells that were labeled at the higher level the same in the lower level
  def subsample(data, thresholds, cluster, annotation, max_length)
    #create data arrays at this threshold as long as the threshold isn't bigger than the size of full data, because that would be impossible
    thresholds.each do |threshold|
      if threshold < max_length
        create_array(cluster, threshold, annotation, data)
      end
    end
  end

  #figure out what level this annotation was created at
  #if you update an annotation's 'Undefined' level, than it will be registered as created at full data
  def subsampled_at
    #get all the annotation arrays
    annotations = user_data_arrays.find_by(array_type: 'annotations').to_a

    #get the labels of this annotation
    vals = self.values
    #default created_at is nothing. created_at is the return string
    created_at = ''

    #max_length is the maximum size of the data, aka the length at no subsampling
    max_length = 0

    #find max_length
    annotations.each do |annot|
      length = annot.values.length
      if length > max_length
        max_length = length
      end
    end

    #so far we don't think undefined exists at these subsamplings
    #undefined can never exist at a subsampling level of 1k, because it is the smallest level possible
    undefined_exists_at_10k = false
    undefined_exists_at_20k = false

    #check were iundefined exists
    if max_length > 10000
      #because max_length > 10k, it's possible that undefined exists
      #check if the annotation array has undefined
      undefined_exists_at_10k = self.user_data_arrays.find_by(array_type: 'annotations', subsample_threshold: 10000).values.include? 'Undefined'
    end

    if max_length > 20000
      #because max_length > 20k, it's possible that undefined exists
      #check if the annotation array has undefined
      undefined_exists_at_20k = self.user_data_arrays.find_by(array_type: 'annotations', subsample_threshold: 20000).values.include? 'Undefined'
    end

    #check if undefined exists at any level, including at full data
    undefined_exists = vals.include? 'Undefined'

    #if undefined exists
    if undefined_exists
      if max_length > 20000
        if undefined_exists_at_20k
          if undefined_exists_at_10k
            #undefined exists at 10k and 20k, so must have been at 1k
            created_at = 'Created at a subsample of 1,000 Cells'
          else
            #undefined exists at 20k but not 10k, so was created at 10k
            created_at = 'Created at a subsample of 10,000 Cells'
          end
        else
          #max length > 20k but undefined doesn't exist at 20k so was created at 20k
          created_at = 'Created at a subsample of 20,000 Cells'
        end
      elsif max_length < 20000 and max_length > 10000
        if undefined_exists_at_10k
          #undefined exists at 10k and 20k, so must have been created at 1k
          created_at = 'Created at a subsample of 1,000 Cells'
        else
          #undefined exists at 20k but not 10k, so was created at 10k
          created_at = 'Created at a subsample of 10,000 Cells'
        end
      elsif max_length < 10000 and max_length > 1000
        #max length is less than 10k. Max length > 1k. Undefined exists, so must be created at 1k.
        created_at = 'Created at a subsample of 1,000 Cells'
    end
    else
      #No undefined means the annotation was created at full data
      created_at = 'Created at Full Data'
    end
    created_at
  end

  #get the annotation's formtted name
  def formatted_annotation_name
    self.name + '--group--user'
  end

  # return all studies that are editable by a given user
  def self.editable(user)
    if user.admin?
      self.where(queued_for_deletion: false).to_a
    else
      annotations = self.where(queued_for_deletion: false, user_id: user._id).to_a
      shares = UserAnnotationShare.where(email: user.email, permission: 'Edit').map(&:user_annotation).select {|a| !a.queued_for_deletion }
      [annotations + shares].flatten.uniq
    end
  end

  # return all studies that are viewable by a given user
  def self.viewable(user)
    if user.admin?
      self.where(queued_for_deletion: false).to_a
    else
      annotations = self.where(queued_for_deletion: false, user_id: user._id).to_a
      shares = UserAnnotationShare.where(email: user.email).map(&:user_annotation).select {|a| !a.queued_for_deletion }
      [annotations + shares].flatten.uniq
    end
  end

  #Share Methods

  # check if a give use can edit study
  def can_edit?(user)
    self.admins.include?(user.email)
  end

  # check if a given user can view study by share (does not take public into account - use Study.viewable(user) instead)
  def can_view?(user)
    self.can_edit?(user) || self.user_annotation_shares.can_view.include?(user.email)
  end

  # check if user can delete a study - only owners can
  def can_delete?(user)
    if self.user_id == user.id || user.admin?
      true
    else
      share = self.user_annotation_shares.detect {|s| s.email == user.email}
      if !share.nil? && share.permission == 'Owner'
        true
      else
        false
      end
    end
  end

  # list of emails for accounts that can edit this study
  def admins
    [self.user.email, self.user_annotation_shares.can_edit, User.where(admin: true).pluck(:email)].flatten.uniq
  end
end
