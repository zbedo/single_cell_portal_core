module AnalysisConfigurationsHelper

  # render a form input based on analysis_parameter attributes
  def render_analysis_parameter_preview(form, parameter, study)
    case parameter.input_type
    when :select
      options = parameter.options_by_association_method(parameter.study_scoped? ? study : nil)
      form.select parameter.config_param_name, options_for_select(options, parameter.apply_to_all? ? options.map(&:last) : nil),
                  {}, multiple: parameter.is_array?, class: 'form-control'
    when :text_field
      form.text_field parameter.config_param_name, value: parameter.parameter_value, class: 'form-control'
    when :number_field
      form.number_field parameter.config_param_name, value: parameter.parameter_value, class: 'form-control'
    when :check_box
      "<div class='checkbox'>#{form.check_box parameter.config_param_name}</div>"
    end
  end

  # render a form input based on analysis_parameter attributes
  def render_analysis_parameter_input(parameter, study)
    case parameter.input_type
    when :select
      options = parameter.options_by_association_method(parameter.study_scoped? ? study : nil)
      select_tag "workflow_#{parameter.config_param_name}", options_for_select(options, parameter.apply_to_all? ? options.map(&:last) : nil),
                  multiple: parameter.is_array?, class: 'form-control', name: "workflow[#{parameter.config_param_name}]"
    when :text_field
      text_field_tag "workflow_#{parameter.config_param_name}", parameter.parameter_value, class: 'form-control', name: "workflow[#{parameter.config_param_name}]"
    when :number_field
      number_field_tag "workflow_#{parameter.config_param_name}", value: parameter.parameter_value, class: 'form-control', name: "workflow[#{parameter.config_param_name}]"
    when :check_box
      "<div class='checkbox'>#{check_box_tag "workflow_#{parameter.config_param_name}", name: "workflow[#{parameter.config_param_name}]"}</div>"
    end
  end
end
