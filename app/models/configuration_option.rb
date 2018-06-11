class ConfigurationOption
  include Mongoid::Document

  belongs_to :admin_configuration
  field :name, type: String
  field :value, type: String

  validates :name, format: ValidationTools::ALPHANUMERIC_ONLY
  validates_uniqueness_of :name, scope: :admin_configuration_id
  validates :value, format: ValidationTools::ALPHANUMERIC_SPACE_DASH

end
