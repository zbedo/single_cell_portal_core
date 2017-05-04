require "test_helper"

class ClusterGroupTest < ActiveSupport::TestCase
  def setup
    @cluster_group = ClusterGroup.first
  end

  # test to validate that subsampling algorithm creates representative samples and also maintains relationships
  def test_generate_subsample_arrays
    # load raw data for comparison and assertions later
    x_array = @cluster_group.concatenate_data_arrays('x', 'coordinates')
    y_array = @cluster_group.concatenate_data_arrays('y', 'coordinates')
    z_array = @cluster_group.concatenate_data_arrays('z', 'coordinates')
    cell_array = @cluster_group.concatenate_data_arrays('text', 'cells')
    category_array = @cluster_group.concatenate_data_arrays('Category', 'annotations')
    intensity_array = @cluster_group.concatenate_data_arrays('Intensity', 'annotations')
    category_hash = @cluster_group.study.study_metadata_values('Category', 'group')
    intensity_hash = @cluster_group.study.study_metadata_values('Intensity', 'numeric')
    original_category_values = @cluster_group.cell_annotations.find {|c| c[:name] == 'Category'}['values'].sort

    # generate subsampled arrays at 1K
    @cluster_group.generate_subsample_arrays(1000, 'Category', 'group', 'cluster')
    @cluster_group.generate_subsample_arrays(1000, 'Intensity', 'numeric', 'cluster')

    # load subsampled arrays
    subsample_category_x = @cluster_group.concatenate_data_arrays('x', 'coordinates', 1000, 'Category--group--cluster')
    subsample_category_y = @cluster_group.concatenate_data_arrays('y', 'coordinates', 1000, 'Category--group--cluster')
    subsample_category_z = @cluster_group.concatenate_data_arrays('z', 'coordinates', 1000, 'Category--group--cluster')
    subsample_category_cells = @cluster_group.concatenate_data_arrays('text', 'cells', 1000, 'Category--group--cluster')
    subsample_category_values = @cluster_group.concatenate_data_arrays('Category', 'annotations', 1000, 'Category--group--cluster')

    # check sizes
    assert subsample_category_x.size == 1000, "x array is wrong size, expected 1000 but found #{subsample_category_x.size}"
    assert subsample_category_y.size == 1000, "y array is wrong size, expected 1000 but found #{subsample_category_y.size}"
    assert subsample_category_z.size == 1000, "z array is wrong size, expected 1000 but found #{subsample_category_z.size}"
    assert subsample_category_cells.size == 1000, "cells array is wrong size, expected 1000 but found #{subsample_category_cells.size}"
    assert subsample_category_values.size == 1000, "values array is wrong size, expected 1000 but found #{subsample_category_values.size}"

    # point arrays should be identical
    assert subsample_category_x == subsample_category_y, 'x and y point arrays are not the same'
    assert subsample_category_x == subsample_category_z, 'x and z point arrays are not the same'

    # grab random element and check that current & original associations are still valid
    random_point = subsample_category_x.sample
    random_cell = "cell_#{random_point}"

    # find random point index to grab other values from
    random_pt_idx = subsample_category_x.index(random_point)
    random_category = subsample_category_values[random_pt_idx]
    subsampled_categories = subsample_category_values.uniq.sort

    assert random_point == subsample_category_y[random_pt_idx], "y array association is incorrect, expected #{subsample_category_y[random_point]} but found #{random_point}"
    assert random_point == subsample_category_z[random_pt_idx], "z array association is incorrect, expected #{subsample_category_z[random_point]} but found #{random_point}"
    assert random_cell == subsample_category_cells[random_pt_idx], "cell array association is incorrect, expected #{subsample_category_cells[random_pt_idx]} but found #{random_cell}"
    assert random_point == x_array[random_point], "original x array association incorrect, expected #{x_array[random_point]} but found #{random_point}"
    assert random_point == y_array[random_point], "original y array association incorrect, expected #{y_array[random_point]} but found #{random_point}"
    assert random_point == z_array[random_point], "original z array association incorrect, expected #{z_array[random_point]} but found #{random_point}"
    assert random_cell == cell_array[random_point], "original cell array association incorrect, expected #{cell_array[random_point]} but found #{random_cell}"
    assert random_category == category_array[random_point], "original category association is incorrect, expected #{category_array[random_point]} but found #{random_category}"
    assert subsampled_categories == original_category_values, "not all categories represented, expected #{original_category_values} but found #{subsampled_categories}"
  end
end
