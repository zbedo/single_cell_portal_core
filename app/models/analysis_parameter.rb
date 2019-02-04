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
  field :associated_model, type: String # SCP model this parameter is associated with, if any (e.g. StudyFile, etc)
  field :associated_model_method, type: String # model instance method that should be called to set value by
  field :associated_model_display_method, type: String # model instance method that should be called to set DISPLAY value by (for dropdowns)
  field :association_filter_attribute, type: String # attribute to filter instances of :associated_model by (e.g. file_type)
  field :association_filter_value, type: String # attribute value to use in above filter (e.g. Expresion Matrix)
  field :output_association_param_name, type: String # parameter name to find output to use when setting associations
  field :output_association_attribute, type: String # association id attribute to set on output files
  field :visible, type: Boolean, default: true # whether or not to render parameter input in submission form
  field :apply_to_all, type: Boolean, default: false # whether or not to apply :associated_model_method to all instances (if an array type input)

  DATA_TYPES = %w(inputs outputs)
  PRIMITIVE_PARAMETER_TYPES = %w(String Int Float File Boolean String? Int? Float? File? Boolean?)
  COMPOUND_PARAMETER_TYPES = %w(Array Map Object)
  ASSOCIATED_MODELS = %w(StudyFile Taxon GenomeAssembly GenomeAnnotation ClusterGroup CellMetadatum)
  ASSOCIATED_MODEL_ATTR_NAMES = [:ASSOCIATED_MODEL_METHOD, :ASSOCIATED_MODEL_DISPLAY_METHOD, :OUTPUT_ASSOCIATION_ATTRIBUTE,
                                 :ASSOCIATION_FILTER_ATTRIBUTE, :ASSOCIATION_FILTER_VALUE]

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

  # determine if parameter is an array type
  def is_array?
    self.parameter_type.split('[').first == 'Array'
  end

  # type of input parameter for array-based inputs
  def array_type
    if self.is_array?
      self.parameter_type.split('[').last.split(']').first
    end
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
