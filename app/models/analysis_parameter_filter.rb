class AnalysisParameterFilter
  include Mongoid::Document

  belongs_to :analysis_parameter
  field :attribute_name, type: String
  field :value, type: String

end
