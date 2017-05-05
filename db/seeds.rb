# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).
#
# Examples:
#
#   cities = City.create([{ name: 'Chicago' }, { name: 'Copenhagen' }])
#   Mayor.create(name: 'Emanuel', city: cities.first)

study = Study.create(name: 'Testing Study')
cluster = ClusterGroup.create(name: 'Test Cluster', study_id: study.id, cluster_type: '3d', cell_annotations: [
    {
        name: 'Category',
        type: 'group',
        values: %w(a b c d)
    },
    {
        name: 'Intensity',
        type: 'numeric',
        values: []
    }
])
# create raw arrays of values to use in DataArrays and StudyMetadatum
category_array = ['a', 'b', 'c', 'd'].repeated_combination(10).to_a.flatten
metadata_label_array = ['E', 'F', 'G', 'H'].repeated_combination(10).to_a.flatten
point_array = 0.upto(category_array.size - 1).to_a
cluster_cell_array = point_array.map {|p| "cell_#{p}"}
all_cell_array = 0.upto(metadata_label_array.size - 1).map {|c| "cell_#{c}"}
intensity_array = point_array.map {|p| rand}
metadata_score_array = all_cell_array.map {|p| rand}
DataArray.create(name: 'x', cluster_name: cluster.name, array_type: 'coordinates', array_index: 1,
                 cluster_group_id: cluster.id, study_id: study.id, values: point_array)
DataArray.create(name: 'y', cluster_name: cluster.name, array_type: 'coordinates', array_index: 1,
                 cluster_group_id: cluster.id, study_id: study.id, values: point_array)
DataArray.create(name: 'z', cluster_name: cluster.name, array_type: 'coordinates', array_index: 1,
                 cluster_group_id: cluster.id, study_id: study.id, values: point_array)
DataArray.create(name: 'text', cluster_name: cluster.name, array_type: 'cells', array_index: 1,
                 cluster_group_id: cluster.id, study_id: study.id, values: cluster_cell_array)
DataArray.create(name: 'Category', cluster_name: cluster.name, array_type: 'annotations', array_index: 1,
                 cluster_group_id: cluster.id, study_id: study.id, values: category_array)
DataArray.create(name: 'Intensity', cluster_name: cluster.name, array_type: 'annotations', array_index: 1,
                 cluster_group_id: cluster.id, study_id: study.id, values: intensity_array)
StudyMetadatum.create(name: 'Label', annotation_type: 'group', study_id: study.id, cell_annotations: Hash[all_cell_array.zip(metadata_label_array)])
StudyMetadatum.create(name: 'Score', annotation_type: 'numeric', study_id: study.id, cell_annotations: Hash[all_cell_array.zip(metadata_score_array)])