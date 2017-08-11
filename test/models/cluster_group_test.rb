require "test_helper"

class ClusterGroupTest < ActiveSupport::TestCase
  def setup
    @cluster_group = ClusterGroup.first
  end

  # test to validate that subsampling algorithm creates representative samples and also maintains relationships
  # checks for cluster-level annotations of type 'group'
  def test_generate_subsample_arrays_group_cluster
    puts "Test method: #{self.method_name}"

    # load raw data for comparison and assertions later
    x_array = @cluster_group.concatenate_data_arrays('x', 'coordinates')
    y_array = @cluster_group.concatenate_data_arrays('y', 'coordinates')
    z_array = @cluster_group.concatenate_data_arrays('z', 'coordinates')
    cell_array = @cluster_group.concatenate_data_arrays('text', 'cells')
    category_array = @cluster_group.concatenate_data_arrays('Category', 'annotations')
    original_category_values = @cluster_group.cell_annotations.find {|c| c[:name] == 'Category'}['values'].sort

    # generate subsampled arrays at 1K
    @cluster_group.generate_subsample_arrays(1000, 'Category', 'group', 'cluster')
    @cluster_group.generate_subsample_arrays(10000, 'Category', 'group', 'cluster')
    @cluster_group.generate_subsample_arrays(20000, 'Category', 'group', 'cluster')

    # load subsampled arrays
    subsample_x = @cluster_group.concatenate_data_arrays('x', 'coordinates', 1000, 'Category--group--cluster')
    subsample_y = @cluster_group.concatenate_data_arrays('y', 'coordinates', 1000, 'Category--group--cluster')
    subsample_z = @cluster_group.concatenate_data_arrays('z', 'coordinates', 1000, 'Category--group--cluster')
    subsample_cells = @cluster_group.concatenate_data_arrays('text', 'cells', 1000, 'Category--group--cluster')
    subsample_values = @cluster_group.concatenate_data_arrays('Category', 'annotations', 1000, 'Category--group--cluster')

    # check sizes
    assert subsample_x.size == 1000, "group x array is wrong size, expected 1000 but found #{subsample_x.size}"
    assert subsample_y.size == 1000, "group y array is wrong size, expected 1000 but found #{subsample_y.size}"
    assert subsample_z.size == 1000, "group z array is wrong size, expected 1000 but found #{subsample_z.size}"
    assert subsample_cells.size == 1000, "group cells array is wrong size, expected 1000 but found #{subsample_cells.size}"
    assert subsample_values.size == 1000, "group values array is wrong size, expected 1000 but found #{subsample_values.size}"

    # point arrays should be identical
    assert subsample_x == subsample_y, 'x and y category point arrays are not the same'
    assert subsample_x == subsample_z, 'x and z category point arrays are not the same'

    # grab random element and check that current & original associations are still valid
    random_point = subsample_x.sample
    random_cell = "cell_#{random_point}"

    # find random point index to grab other values from for group subsample
    random_group_pt_idx = subsample_x.index(random_point)
    random_category = subsample_values[random_group_pt_idx]
    subsampled_categories = subsample_values.uniq.sort

    assert random_point == subsample_y[random_group_pt_idx], "y array group association is incorrect, expected #{subsample_y[random_group_pt_idx]} but found #{random_point}"
    assert random_point == subsample_z[random_group_pt_idx], "z array group association is incorrect, expected #{subsample_z[random_group_pt_idx]} but found #{random_point}"
    assert random_cell == subsample_cells[random_group_pt_idx], "cell array group association is incorrect, expected #{subsample_cells[random_group_pt_idx]} but found #{random_cell}"
    assert random_point == x_array[random_point], "original x array group association incorrect, expected #{x_array[random_point]} but found #{random_point}"
    assert random_point == y_array[random_point], "original y array group association incorrect, expected #{y_array[random_point]} but found #{random_point}"
    assert random_point == z_array[random_point], "original z array group association incorrect, expected #{z_array[random_point]} but found #{random_point}"
    assert random_cell == cell_array[random_point], "original cell array group association incorrect, expected #{cell_array[random_point]} but found #{random_cell}"
    assert random_category == category_array[random_point], "original category association is incorrect, expected #{category_array[random_point]} but found #{random_category}"
    # extra assertion to make sure all group categories are represented
    assert subsampled_categories == original_category_values, "not all categories represented, expected #{original_category_values} but found #{subsampled_categories}"

    puts "Test method: #{self.method_name} successful!"
  end

  # test to validate that subsampling algorithm creates representative samples and also maintains relationships
  # checks for cluster-level annotations of type 'numeric'
  def test_generate_subsample_arrays_numeric_cluster
    puts "Test method: #{self.method_name}"

    # load raw data for comparison and assertions later
    x_array = @cluster_group.concatenate_data_arrays('x', 'coordinates')
    y_array = @cluster_group.concatenate_data_arrays('y', 'coordinates')
    z_array = @cluster_group.concatenate_data_arrays('z', 'coordinates')
    cell_array = @cluster_group.concatenate_data_arrays('text', 'cells')
    intensity_array = @cluster_group.concatenate_data_arrays('Intensity', 'annotations')

    # generate subsampled arrays at 1K
    @cluster_group.generate_subsample_arrays(1000, 'Intensity', 'numeric', 'cluster')

    # load subsampled arrays
    subsample_x = @cluster_group.concatenate_data_arrays('x', 'coordinates', 1000, 'Intensity--numeric--cluster')
    subsample_y = @cluster_group.concatenate_data_arrays('y', 'coordinates', 1000, 'Intensity--numeric--cluster')
    subsample_z = @cluster_group.concatenate_data_arrays('z', 'coordinates', 1000, 'Intensity--numeric--cluster')
    subsample_cells = @cluster_group.concatenate_data_arrays('text', 'cells', 1000, 'Intensity--numeric--cluster')
    subsample_values = @cluster_group.concatenate_data_arrays('Intensity', 'annotations', 1000, 'Intensity--numeric--cluster')

    # check sizes
    assert subsample_x.size == 1000, "intensity x array is wrong size, expected 1000 but found #{subsample_x.size}"
    assert subsample_y.size == 1000, "intensity y array is wrong size, expected 1000 but found #{subsample_y.size}"
    assert subsample_z.size == 1000, "intensity z array is wrong size, expected 1000 but found #{subsample_z.size}"
    assert subsample_cells.size == 1000, "intensity cells array is wrong size, expected 1000 but found #{subsample_cells.size}"
    assert subsample_values.size == 1000, "intensity values array is wrong size, expected 1000 but found #{subsample_values.size}"

    # point arrays should be identical
    assert subsample_x == subsample_y, 'x and y intensity point arrays are not the same'
    assert subsample_x == subsample_z, 'x and z intensity point arrays are not the same'

    # grab random element and check that current & original associations are still valid
    random_point = subsample_x.sample
    random_cell = "cell_#{random_point}"
    random_pt_idx = subsample_x.index(random_point)
    random_intensity = subsample_values[random_pt_idx]

    assert random_point == subsample_y[random_pt_idx], "y array numeric association is incorrect, expected #{subsample_y[random_pt_idx]} but found #{random_point}"
    assert random_point == subsample_z[random_pt_idx], "z array numeric association is incorrect, expected #{subsample_z[random_pt_idx]} but found #{random_point}"
    assert random_cell == subsample_cells[random_pt_idx], "cell array numeric association is incorrect, expected #{subsample_cells[random_pt_idx]} but found #{random_cell}"
    assert random_point == x_array[random_point], "original x array numeric association incorrect, expected #{x_array[random_point]} but found #{random_point}"
    assert random_point == y_array[random_point], "original y array numeric association incorrect, expected #{y_array[random_point]} but found #{random_point}"
    assert random_point == z_array[random_point], "original z array numeric association incorrect, expected #{z_array[random_point]} but found #{random_point}"
    assert random_cell == cell_array[random_point], "original cell array numeric association incorrect, expected #{cell_array[random_point]} but found #{random_cell}"
    assert random_intensity == intensity_array[random_point], "original category association is incorrect, expected #{intensity_array[random_point]} but found #{random_intensity}"

    puts "Test method: #{self.method_name} successful!"
  end

  # test to validate that subsampling algorithm creates representative samples and also maintains relationships
  # checks for study-level annotations of type 'group'
  def test_generate_subsample_arrays_group_study
    puts "Test method: #{self.method_name}"

    # load raw data for comparison and assertions later
    x_array = @cluster_group.concatenate_data_arrays('x', 'coordinates')
    y_array = @cluster_group.concatenate_data_arrays('y', 'coordinates')
    z_array = @cluster_group.concatenate_data_arrays('z', 'coordinates')
    cell_array = @cluster_group.concatenate_data_arrays('text', 'cells')

    # generate subsampled arrays at 1K
    @cluster_group.generate_subsample_arrays(1000, 'Label', 'group', 'study')
    @cluster_group.generate_subsample_arrays(10000, 'Label', 'group', 'study')
    @cluster_group.generate_subsample_arrays(20000, 'Label', 'group', 'study')

    # load subsampled arrays (study based)
    subsample_x = @cluster_group.concatenate_data_arrays('x', 'coordinates', 1000, 'Label--group--study')
    subsample_y = @cluster_group.concatenate_data_arrays('y', 'coordinates', 1000, 'Label--group--study')
    subsample_z = @cluster_group.concatenate_data_arrays('z', 'coordinates', 1000, 'Label--group--study')
    subsample_cells = @cluster_group.concatenate_data_arrays('text', 'cells', 1000, 'Label--group--study')

    # check sizes
    assert subsample_x.size == 1000, "group x array is wrong size, expected 1000 but found #{subsample_x.size}"
    assert subsample_y.size == 1000, "group y array is wrong size, expected 1000 but found #{subsample_y.size}"
    assert subsample_z.size == 1000, "group z array is wrong size, expected 1000 but found #{subsample_z.size}"
    assert subsample_cells.size == 1000, "group cells array is wrong size, expected 1000 but found #{subsample_cells.size}"

    # point arrays should be identical
    assert subsample_x == subsample_y, 'x and y category point arrays are not the same'
    assert subsample_x == subsample_z, 'x and z category point arrays are not the same'

    # grab random element and check that current & original associations are still valid
    random_point = subsample_x.sample
    random_cell = "cell_#{random_point}"

    # find random point index to grab other values from for group subsample
    random_group_pt_idx = subsample_x.index(random_point)

    assert random_point == subsample_y[random_group_pt_idx], "y array group association is incorrect, expected #{subsample_y[random_group_pt_idx]} but found #{random_point}"
    assert random_point == subsample_z[random_group_pt_idx], "z array group association is incorrect, expected #{subsample_z[random_group_pt_idx]} but found #{random_point}"
    assert random_cell == subsample_cells[random_group_pt_idx], "cell array group association is incorrect, expected #{subsample_cells[random_group_pt_idx]} but found #{random_cell}"
    assert random_point == x_array[random_point], "original x array group association incorrect, expected #{x_array[random_point]} but found #{random_point}"
    assert random_point == y_array[random_point], "original y array group association incorrect, expected #{y_array[random_point]} but found #{random_point}"
    assert random_point == z_array[random_point], "original z array group association incorrect, expected #{z_array[random_point]} but found #{random_point}"
    assert random_cell == cell_array[random_point], "original cell array group association incorrect, expected #{cell_array[random_point]} but found #{random_cell}"

    puts "Test method: #{self.method_name} successful!"
  end

  # test to validate that subsampling algorithm creates representative samples and also maintains relationships
  # checks for study-level annotations of type 'numeric'
  def test_generate_subsample_arrays_numeric_study
    puts "Test method: #{self.method_name}"

    # load raw data for comparison and assertions later
    x_array = @cluster_group.concatenate_data_arrays('x', 'coordinates')
    y_array = @cluster_group.concatenate_data_arrays('y', 'coordinates')
    z_array = @cluster_group.concatenate_data_arrays('z', 'coordinates')
    cell_array = @cluster_group.concatenate_data_arrays('text', 'cells')

    # generate subsampled arrays at 1K
    @cluster_group.generate_subsample_arrays(1000, 'Score', 'numeric', 'study')

    # load subsampled arrays (study based)
    subsample_x = @cluster_group.concatenate_data_arrays('x', 'coordinates', 1000, 'Score--numeric--study')
    subsample_y = @cluster_group.concatenate_data_arrays('y', 'coordinates', 1000, 'Score--numeric--study')
    subsample_z = @cluster_group.concatenate_data_arrays('z', 'coordinates', 1000, 'Score--numeric--study')
    subsample_cells = @cluster_group.concatenate_data_arrays('text', 'cells', 1000, 'Score--numeric--study')

    # check sizes
    assert subsample_x.size == 1000, "group x array is wrong size, expected 1000 but found #{subsample_x.size}"
    assert subsample_y.size == 1000, "group y array is wrong size, expected 1000 but found #{subsample_y.size}"
    assert subsample_z.size == 1000, "group z array is wrong size, expected 1000 but found #{subsample_z.size}"
    assert subsample_cells.size == 1000, "group cells array is wrong size, expected 1000 but found #{subsample_cells.size}"

    # point arrays should be identical
    assert subsample_x == subsample_y, 'x and y category point arrays are not the same'
    assert subsample_x == subsample_z, 'x and z category point arrays are not the same'

    # grab random element and check that current & original associations are still valid
    random_point = subsample_x.sample
    random_cell = "cell_#{random_point}"

    # find random point index to grab other values from for group subsample
    random_group_pt_idx = subsample_x.index(random_point)

    assert random_point == subsample_y[random_group_pt_idx], "y array group association is incorrect, expected #{subsample_y[random_group_pt_idx]} but found #{random_point}"
    assert random_point == subsample_z[random_group_pt_idx], "z array group association is incorrect, expected #{subsample_z[random_group_pt_idx]} but found #{random_point}"
    assert random_cell == subsample_cells[random_group_pt_idx], "cell array group association is incorrect, expected #{subsample_cells[random_group_pt_idx]} but found #{random_cell}"
    assert random_point == x_array[random_point], "original x array group association incorrect, expected #{x_array[random_point]} but found #{random_point}"
    assert random_point == y_array[random_point], "original y array group association incorrect, expected #{y_array[random_point]} but found #{random_point}"
    assert random_point == z_array[random_point], "original z array group association incorrect, expected #{z_array[random_point]} but found #{random_point}"
    assert random_cell == cell_array[random_point], "original cell array group association incorrect, expected #{cell_array[random_point]} but found #{random_cell}"

    puts "Test method: #{self.method_name} successful!"
  end
end

