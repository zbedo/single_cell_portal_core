module AnalysisConfigurationsHelper

  # render a form input based on analysis_parameter attributes (for preview only)
  def render_analysis_parameter_preview(form, parameter, study)
    case parameter.input_type
    when :select
      options = parameter.options_by_association_method(parameter.study_scoped? ? study : nil)
      if parameter.apply_to_all?
        form.select "#{parameter.config_param_name}[]", options_for_select(options, options.map(&:last)),
                    {}, multiple: true, class: 'form-control'
      else
        form.select parameter.config_param_name, options_for_select(options), {}, class: 'form-control'
      end
    when :text_field
      form.text_field parameter.config_param_name, value: parameter.parameter_value, class: 'form-control'
    when :number_field
      form.number_field parameter.config_param_name, value: parameter.parameter_value, class: 'form-control'
    when :check_box
      form.check_box parameter.config_param_name
    end
  end

  # render a form input based on analysis_parameter attributes
  def render_analysis_parameter_input(parameter, study)
    case parameter.input_type
    when :select
      options = parameter.options_by_association_method(parameter.study_scoped? ? study : nil)
      if parameter.apply_to_all?
        select_tag "workflow_inputs_#{parameter.config_param_name}#{parameter.config_param_name}[]",
                    options_for_select(options, options.map(&:last)), multiple: true, class: 'form-control',
                    name: "workflow[inputs][#{parameter.config_param_name}][]"
      else
        select_tag parameter.config_param_name, options_for_select(options), class: 'form-control',
                   name: "workflow[inputs][#{parameter.config_param_name}]"
      end
    when :text_field
      text_field_tag "workflow_inputs_#{parameter.config_param_name}", parameter.parameter_value, class: 'form-control', name: "workflow[inputs][#{parameter.config_param_name}]"
    when :number_field
      number_field_tag "workflow_inputs_#{parameter.config_param_name}", parameter.parameter_value, class: 'form-control', name: "workflow[inputs][#{parameter.config_param_name}]"
    when :check_box
      check_box_tag "workflow_inputs_#{parameter.config_param_name}"
    end
  end
end
