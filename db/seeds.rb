# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).
#
# Examples:
#
#   cities = City.create([{ name: 'Chicago' }, { name: 'Copenhagen' }])
#   Mayor.create(name: 'Emanuel', city: cities.first)

study = Study.create(name: 'Testing Study', description: '<p>This is the test study.</p>', data_dir: 'none')
expression_file = StudyFile.create(name: 'expression_matrix.txt', upload_file_name: 'expression_matrix.txt', study_id: study.id, file_type: 'Expression Matrix', y_axis_label: 'Expression Scores')
cluster_file = StudyFile.create!(name: 'Test Cluster', upload_file_name: 'coordinates.txt', study_id: study.id, file_type: 'Cluster', x_axis_label: 'X', y_axis_label: 'Y', z_axis_label: 'Z')

cluster = ClusterGroup.create(name: 'Test Cluster', study_id: study.id, study_file_id: cluster_file.id, cluster_type: '3d', cell_annotations: [
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
label_hash = Hash[all_cell_array.zip(metadata_label_array)]
score_hash = Hash[all_cell_array.zip(metadata_score_array)]
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
StudyMetadatum.create(name: 'Label', annotation_type: 'group', study_id: study.id, cell_annotations: label_hash)
StudyMetadatum.create(name: 'Score', annotation_type: 'numeric', study_id: study.id, cell_annotations: score_hash)
ExpressionScore.create(gene: 'Gene_1', searchable_gene: 'gene_1', study_id: study.id, study_file_id: expression_file.id, scores: score_hash)
ExpressionScore.create(gene: 'Gene_2', searchable_gene: 'gene_2', study_id: study.id, study_file_id: expression_file.id, scores: score_hash)