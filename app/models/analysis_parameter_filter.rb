class AnalysisParameterFilter
  include Mongoid::Document

  belongs_to :analysis_parameter
  field :attribute_name, type: String
  field :value, type: String

  ASSOCIATED_MODEL_FILTER_ATTRS = [:ANALYSIS_PARAMETER_FILTER_ATTRIBUTE_NAME, :ANALYSIS_PARAMETER_FILTER_VALUE]

  # used to populate dropdowns in analysis_parameter_filters_form, not for use with user inputs
  def filter_attributes
    if self.analysis_parameter.present? && self.analysis_parameter.associated_model.present?
      model = self.analysis_parameter.associated_model_class
      model::ANALYSIS_PARAMETER_FILTERS.keys
    else
      []
    end
  end

  # used to populate dropdowns in analysis_parameter_filters_form, not for use with user inputs
  def filter_values
    if self.analysis_parameter.present? && self.analysis_parameter.associated_model.present?
      model = self.analysis_parameter.associated_model_class
      model::ANALYSIS_PARAMETER_FILTERS[self.attribute_name]
    else
      []
    end
  end
end