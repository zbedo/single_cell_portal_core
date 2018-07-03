class ConfigurationOption
  include Mongoid::Document

  belongs_to :admin_configuration
  field :name, type: String
  field :value, type: String

  validates_format_of :name, with: ValidationTools::ALPHANUMERIC_ONLY,
                      message: ValidationTools::ALPHANUMERIC_ONLY_ERROR
  validates_uniqueness_of :name, scope: :admin_configuration_id
  validates_format_of :value, with: ValidationTools::OBJECT_LABELS,
                      message: ValidationTools::OBJECT_LABELS_ERROR

end
