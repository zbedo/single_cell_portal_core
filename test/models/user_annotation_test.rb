require "test_helper"

class UserAnnotationTest < ActiveSupport::TestCase
  def setup
    @user = User.first
    @cluster = ClusterGroup.first
    @study = Study.first
  end

   def test_generate_user_annotation_full_data
    puts "Test method: #{self.method_name}"

    #Generate keys
    num_keys = rand(8) + 2
    keys = []
    i = 0
    while i < num_keys
      keys.push(i.to_s)
      i += 1
    end
    # test at full data first
    potential_labels = %w[Label--group--study Category--group--cluster]
    loaded_annotation = potential_labels.sample
    puts "loaded_annotation: #{loaded_annotation}"
    @user_annotation = UserAnnotation.create(user_id: @user.id, study_id: @study.id, cluster_group_id: @cluster.id, values: keys, name: 'fulldata')

    #build user_data_array_attributes
    user_data_arrays_attributes = {}

    #Get all the cell names and shuffle to randomize their order
    cell_array = @cluster.concatenate_data_arrays('text', 'cells').shuffle
    len_segment = (cell_array.length / num_keys).floor

    #Spoof the parameter hash passed in the site controller
    keys.each_with_index do |key, i|
      cell_names = []
      add = cell_array.slice!(0, len_segment)
      if i+1  == keys.length
        cell_names.concat(cell_array)
      end
      cell_names.concat(add)

      user_data_arrays_attributes["#{key}"] = {:values => cell_names.join(','),  :name => key}
    end

    #Create the data arrays
    @user_annotation.initialize_user_data_arrays(user_data_arrays_attributes, nil, nil, loaded_annotation)

    #Check some random points and see if they were created correctly
    data_arrays_cells = @user_annotation.user_data_arrays.where(array_type: 'cells').first.values
    data_arrays_annotations = @user_annotation.user_data_arrays.where(array_type: 'annotations').first.values
    keys.each do
      random_cell_num = rand(data_arrays_cells.length).floor

      value_in_array = data_arrays_annotations[random_cell_num]
      original_hash = user_data_arrays_attributes["#{value_in_array}"][:values].split(',')

      puts "original hash should include #{data_arrays_cells[random_cell_num]}"

      assert (original_hash.include? data_arrays_cells[random_cell_num]), "#{original_hash} should include #{data_arrays_cells[random_cell_num]}"
    end

    #Check that created at method works correctly
    created_at = @user_annotation.subsampled_at
    assert created_at == 'Created at Full Data', "Incorrect created at, '#{created_at} should be 'Created at Full Data"

    #Check that 16 data arrays were created
    num_data_arrays = @user_annotation.user_data_arrays.all.to_a.count
    assert num_data_arrays == 16, "Incorrect number of user data arrays, #{num_data_arrays} instead of 16"

    puts "Test method: #{self.method_name} successful!"
   end

  def test_generate_user_annotation_twenty_k_data
    puts "Test method: #{self.method_name}"

    #Generate keys
    num_keys = rand(8) + 2
    keys = []
    i = 0
    while i < num_keys
      keys.push(i.to_s)
      i += 1
    end
    # test at 20,000 subsample data
    potential_labels = %w[Label--group--study Category--group--cluster]
    loaded_annotation = potential_labels.sample
    puts "loaded_annotation: #{loaded_annotation}"
    @user_annotation = UserAnnotation.create(user_id: @user.id, study_id: @study.id, cluster_group_id: @cluster.id, values: keys, name: 'twenty')

    #build user_data_array_attributes
    user_data_arrays_attributes = {}

    #Get all the cell names and shuffle to randomize their order
    cell_array = @cluster.concatenate_data_arrays('text', 'cells', 20000, loaded_annotation).shuffle
    len_segment = (cell_array.length / num_keys).floor

    #Spoof the parameter hash passed in the site controller
    keys.each_with_index do |key, i|
      cell_names = []
      add = cell_array.slice!(0, len_segment)
      if i+1  == keys.length
        cell_names.concat(cell_array)
      end
      cell_names.concat(add)

      user_data_arrays_attributes["#{key}"] = {:values => cell_names.join(','),  :name => key}
    end

    #Create the data arrays
    @user_annotation.initialize_user_data_arrays(user_data_arrays_attributes, loaded_annotation, 20000, loaded_annotation)

    #Check that 16 data arrays were created
    num_data_arrays = @user_annotation.user_data_arrays.all.to_a.count
    assert num_data_arrays == 16, "Incorrect number of user data arrays, #{num_data_arrays} instead of 16"

    #Check some random points and see if they were created correctly
    data_arrays_cells = @user_annotation.user_data_arrays.where(array_type: 'cells', subsample_threshold: 20000).first.values
    data_arrays_annotations = @user_annotation.user_data_arrays.where(array_type: 'annotations', subsample_threshold: 20000).first.values
    keys.each do
      random_cell_num = rand(data_arrays_cells.length).floor

      value_in_array = data_arrays_annotations[random_cell_num]
      original_hash = user_data_arrays_attributes["#{value_in_array}"][:values].split(',')

      puts "original hash should include #{data_arrays_cells[random_cell_num]}"

      assert (original_hash.include? data_arrays_cells[random_cell_num]), "#{original_hash} should include #{data_arrays_cells[random_cell_num]}"
    end

    #Check that created at method works correctly
    created_at = @user_annotation.subsampled_at
    assert created_at == 'Created at a subsample of 20,000 Cells', "Incorrect created at, '#{created_at} should be 'Created at a subsample of 20,000 Cells"

    puts "Test method: #{self.method_name} successful!"
  end

  def test_generate_user_annotation_ten_k_data
    puts "Test method: #{self.method_name}"

    #Generate keys
    num_keys = rand(8) + 2
    keys = []
    i = 0
    while i < num_keys
      keys.push(i.to_s)
      i += 1
    end
    # test at 10,000 subsample data
    potential_labels = %w[Label--group--study Category--group--cluster]
    loaded_annotation = potential_labels.sample

    @user_annotation = UserAnnotation.create(user_id: @user.id, study_id: @study.id, cluster_group_id: @cluster.id, values: keys, name: 'ten')

    #build user_data_array_attributes
    user_data_arrays_attributes = {}

    #Get all the cell names and shuffle to randomize their order
    cell_array = @cluster.concatenate_data_arrays('text', 'cells', 10000, loaded_annotation).shuffle
    len_segment = (cell_array.length / num_keys).floor

    #Spoof the parameter hash passed in the site controller
    keys.each_with_index do |key, i|
      cell_names = []
      add = cell_array.slice!(0, len_segment)
      if i+1  == keys.length
        cell_names.concat(cell_array)
      end
      cell_names.concat(add)

      user_data_arrays_attributes["#{key}"] = {:values => cell_names.join(','),  :name => key}
    end

    #Create the data arrays
    @user_annotation.initialize_user_data_arrays(user_data_arrays_attributes, loaded_annotation, 10000, loaded_annotation)

    #Check that 16 data arrays were created
    num_data_arrays = @user_annotation.user_data_arrays.all.to_a.count
    assert num_data_arrays == 16, "Incorrect number of user data arrays, #{num_data_arrays} instead of 16"

    #Check some random points and see if they were created correctly
    data_arrays_cells = @user_annotation.user_data_arrays.where(array_type: 'cells', subsample_threshold: 10000).first.values
    data_arrays_annotations = @user_annotation.user_data_arrays.where(array_type: 'annotations', subsample_threshold: 10000).first.values
    keys.each do
      random_cell_num = rand(data_arrays_cells.length).floor

      value_in_array = data_arrays_annotations[random_cell_num]
      original_hash = user_data_arrays_attributes["#{value_in_array}"][:values].split(',')

      puts "original hash should include #{data_arrays_cells[random_cell_num]}"

      assert (original_hash.include? data_arrays_cells[random_cell_num]), "#{original_hash} should include #{data_arrays_cells[random_cell_num]}"
    end

    #Check that created at method works correctly
    created_at = @user_annotation.subsampled_at
    assert created_at == 'Created at a subsample of 10,000 Cells', "Incorrect created at, '#{created_at} should be 'Created at a subsample of 10,000 Cells"

    puts "Test method: #{self.method_name} successful!"
  end

  def test_generate_user_annotation_one_k_data
    puts "Test method: #{self.method_name}"

    #Generate keys
    num_keys = rand(8) + 2
    keys = []
    i = 0
    while i < num_keys
      keys.push(i.to_s)
      i += 1
    end
    # test at 1,000 subsample
    potential_labels = %w[Label--group--study Category--group--cluster]
    loaded_annotation = potential_labels.sample
    puts "loaded_annotation: #{loaded_annotation}"
    @user_annotation = UserAnnotation.create(user_id: @user.id, study_id: @study.id, cluster_group_id: @cluster.id, values: keys, name: 'one')

    #build user_data_array_attributes
    user_data_arrays_attributes = {}

    #Get all the cell names and shuffle to randomize their order
    cell_array = @cluster.concatenate_data_arrays('text', 'cells', 1000, loaded_annotation).shuffle
    len_segment = (cell_array.length / num_keys).floor

    #Spoof the parameter hash passed in the site controller
    keys.each_with_index do |key, i|
      cell_names = []
      add = cell_array.slice!(0, len_segment)
      if i+1  == keys.length
        cell_names.concat(cell_array)
      end
      cell_names.concat(add)

      user_data_arrays_attributes["#{key}"] = {:values => cell_names.join(','),  :name => key}
    end

    #Create the data arrays
    @user_annotation.initialize_user_data_arrays(user_data_arrays_attributes, loaded_annotation, 1000, loaded_annotation)

    #Check that 16 data arrays were created
    num_data_arrays = @user_annotation.user_data_arrays.all.to_a.count
    assert num_data_arrays == 16, "Incorrect number of user data arrays, #{num_data_arrays} instead of 16"

    #Check some random points and see if they were created correctly
    data_arrays_cells = @user_annotation.user_data_arrays.where(array_type: 'cells', subsample_threshold: 1000).first.values
    data_arrays_annotations = @user_annotation.user_data_arrays.where(array_type: 'annotations', subsample_threshold: 1000).first.values
    keys.each do
      random_cell_num = rand(data_arrays_cells.length).floor

      value_in_array = data_arrays_annotations[random_cell_num]
      original_hash = user_data_arrays_attributes["#{value_in_array}"][:values].split(',')

      puts "original hash should include #{data_arrays_cells[random_cell_num]}"

      assert (original_hash.include? data_arrays_cells[random_cell_num]), "#{original_hash} should include #{data_arrays_cells[random_cell_num]}"
    end

    #Check that created at method works correctly
    created_at = @user_annotation.subsampled_at
    assert created_at == 'Created at a subsample of 1,000 Cells', "Incorrect created at, '#{created_at} should be 'Created at a subsample of 1,000 Cells"

    puts "Test method: #{self.method_name} successful!"
  end
end
