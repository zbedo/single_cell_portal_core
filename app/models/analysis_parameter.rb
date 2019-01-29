class AnalysisParameter
  include Mongoid::Document
  extend ValidationTools
  extend ErrorTracker

  belongs_to :analysis_configuration

  field :data_type, type: String # input, output
  field :call_name, type: String # name of WDL task this input
  field :parameter_type, type: String # type of the parameter (from primitive/compound types)
  field :parameter_name, type: String # name of the parameter from the WDL
  field :parameter_value, type: String # value of the parameter (optional)
  field :optional, type: Boolean, default: false # parameter optional?
  field :portal_file_type, type: String

  DATA_TYPES = %w(inputs outputs)
  PRIMITIVE_PARAMETER_TYPES = %w(String Int Float File Boolean String? Int? Float? File? Boolean?)
  COMPOUND_PARAMETER_TYPES = %w(Array Map Object)

  validates_presence_of :data_type, :call_name, :parameter_type, :parameter_name
  validates_format_of :parameter_name, with: ValidationTools::ALPHANUMERIC_PERIOD,
                      message: ValidationTools::ALPHANUMERIC_PERIOD_ERROR
  validates_format_of :call_name, with: ValidationTools::FILENAME_CHARS, message: ValidationTools::FILENAME_CHARS_ERROR
  validates_uniqueness_of :parameter_name, scope: [:data_type, :call_name, :analysis_configuration_id]
  validates_inclusion_of :data_type, in: DATA_TYPES
  validate :validate_parameter_type
  validate :validate_parameter_value_by_type, unless: proc {|attributes| attributes.parameter_value.blank?}

  # get the call & parameter name together for use in Methods Repository configuration objects
  def config_param_name
    "#{self.call_name}.#{self.parameter_name}"
  end
  private

  # ensure parameter type conforms to WDL input types
  def validate_parameter_type
    if PRIMITIVE_PARAMETER_TYPES.include? self.parameter_type || self.parameter_type === 'Object'
      true
    elsif self.parameter_type.include?('[') # compound types have brackets []
      # extract primitives from complex type
      raw_primitives = self.parameter_type.split('[').last
      raw_primitives.gsub!(/]\??/, '')
      primitives = raw_primitives.split(',').map(&:strip)
      if self.parameter_type.start_with?('Array')
        # there is only one primitive type from the control list
        unless primitives.size === 1 && PRIMITIVE_PARAMETER_TYPES.include?(primitives.first)
          errors.add(:parameter_type, "has an invalid primitive type: #{(primitives - PRIMITIVE_PARAMETER_TYPES).join(', ')}")
        end
      elsif self.parameter_type.start_with?('Map')
        # there are two primitive types, and the intersection is the same as the unique list of primitives
        unless primitives.size === 2 && (primitives & PRIMITIVE_PARAMETER_TYPES === primitives.uniq)
          errors.add(:parameter_type, "has an invalid primitive type: #{(primitives - PRIMITIVE_PARAMETER_TYPES).join(', ')}")
        end
      else
        errors.add(:parameter_type, "has an invalid complex type: #{self.parameter_type.split('[').first}")
      end
    else
      errors.add(:parameter_type, "has an invalid value: #{self.parameter_type}")
    end
  end

  # validate parameter values depending on their type
  def validate_parameter_value_by_type
    has_validation_error = false
    case self.parameter_type
    when 'String'
      unless self.parameter_value.start_with?('"') && self.parameter_value.end_with?('"')
        has_validation_error = true
      end
    when 'Int'
      unless self.parameter_value.is_a?(Integer)
        has_validation_error = true
      end
    when 'Float'
      unless self.parameter_value.is_a?(Float)
        has_validation_error = true
      end
    when 'File'
      unless self.parameter_value.start_with?('"gs://')
        has_validation_error = true
      end
    else
      true # complex data types are too complicated to validate, so punt
    end
    if has_validation_error
      errors.add(:parameter_value, "is not a valid #{self.parameter_type} value: #{self.parameter_value}.")
    end
  end
end
