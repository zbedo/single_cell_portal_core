class ConfigurationOption
  include Mongoid::Document

  belongs_to :admin_configuration
  field :name, type: String
  field :value, type: String

  validates_uniqueness_of :name, scope: :admin_configuration_id
end
