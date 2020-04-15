require "test_helper"

class CellMetadatumTest < ActiveSupport::TestCase

  test 'should not visualize unique group annotations over 100' do
    puts "#{File.basename(__FILE__)}: #{self.method_name}"

    # setup
    annotation_values = []
    200.times { annotation_values << SecureRandom.uuid }
    @cell_metadatum = CellMetadatum.new(name: 'Group Count Test', annotation_type: 'group', values: annotation_values)

    # assert unique group annotations > 100 cannot visualize
    can_visualize = @cell_metadatum.can_visualize?
    assert !can_visualize, "Should not be able to visualize group annotation with more that 100 unique values: #{can_visualize}"

    # check that numeric annotations are still fine
    @cell_metadatum.annotation_type = 'numeric'
    @cell_metadatum.values = []
    can_visualize = @cell_metadatum.can_visualize?
    assert can_visualize, "Should be able to visualize numeric annotations at any level: #{can_visualize}"

    puts "#{File.basename(__FILE__)}: #{self.method_name} successful!"
  end

  test 'should not visualize ontology id based annotations' do
    puts "#{File.basename(__FILE__)}: #{self.method_name}"

    # setup
    study = Study.first
    metadata_file = study.metadata_file
    @disease = CellMetadatum.create(study_id: study.id, study_file_id: metadata_file.id, name: 'disease',
                                    annotation_type: 'group', values: %w(MONDO_0000001))
    @disease_labels = CellMetadatum.create(study_id: study.id, study_file_id: metadata_file.id, name: 'disease__ontology_label',
                                           annotation_type: 'group', values: ['disease or disorder'])

    # ensure id-based annotations do not visualize
    assert @disease.is_ontology_ids?, "Did not correctly identify #{@disease.name} annotation as ontology ID based"
    refute @disease_labels.is_ontology_ids?, "Incorrectly labelled #{@disease_labels.name} annotation as ontology ID based"
    refute @disease.can_visualize?,
           "Should not be able to view #{@disease.name} annotation: values: #{@disease.values.size}, is_ontology_ids?: #{@disease.is_ontology_ids?}"
    refute @disease_labels.can_visualize?,
           "Should not be able to view #{@disease_labels.name} annotation: values: #{@disease_labels.values.size}, is_ontology_ids?: #{@disease_labels.is_ontology_ids?}"

    # update disease__ontology_label to have more than one value
    @disease_labels.values << 'tuberculosis'
    assert @disease_labels.can_visualize?,
           "Should be able to view #{@disease_labels.name} annotation: values: #{@disease_labels.values.size}, is_ontology_ids?: #{@disease_labels.is_ontology_ids?}"

    # clean up
    @disease.destroy
    @disease_labels.destroy

    puts "#{File.basename(__FILE__)}: #{self.method_name} successful!"
  end
end
