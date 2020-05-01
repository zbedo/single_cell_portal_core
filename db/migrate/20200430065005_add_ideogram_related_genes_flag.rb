class AddIdeogramRelatedGenesFlag < Mongoid::Migration
  class FeatureFlagMigrator
    include Mongoid::Document
    store_in collection: 'feature_flags'
    field :name, type: String
    field :default_value, type: Boolean, default: false
    field :description, type: String
  end
  def self.up
    FeatureFlagMigrator.create!(name: 'ideogram_related_genes',
                                default_value: false,
                                description: 'Whether related genes are shown in ideogram for single-gene search in Study Overview')
  end

  def self.down
    FeatureFlagMigrator.find_by(name: 'ideogram_related_genes').destroy
  end
end
