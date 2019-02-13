class AnalysisConfiguration
  include Mongoid::Document
  extend ValidationTools
  extend ErrorTracker

  belongs_to :user

  field :namespace, type: String
  field :name, type: String
  field :snapshot, type: Integer
  field :configuration_namespace, type: String
  field :configuration_name, type: String
  field :configuration_snapshot, type: Integer
  field :synopsis, type: String
  field :entity_type, type: String

  validate :ensure_wdl_keys
  validates_presence_of :namespace, :name, :snapshot, :configuration_namespace, :configuration_name, :configuration_snapshot
  validates_format_of :namespace, :name, :snapshot, :configuration_namespace, :configuration_name, :configuration_snapshot,
                      with: ValidationTools::ALPHANUMERIC_DASH, message: ValidationTools::ALPHANUMERIC_DASH_ERROR
  validates_uniqueness_of :snapshot, scope: [:namespace, :name]
  validates_uniqueness_of :configuration_snapshot, scope: [:configuration_namespace, :configuration_name]
  validate :validate_wdl_accessibility
  validate :validate_wdl_configuration

  ENTITY_TYPES = %w(participant sample)

  has_many :analysis_parameters, dependent: :delete do
    def inputs
      where(data_type: 'inputs')
    end

    def outputs
      where(data_type: 'outputs')
    end
  end

  after_create :load_parameters_from_wdl!
  after_create :set_synopsis!

  # returns an array of all available analysis_configurations for use in dropdown menus
  def self.available_analyses
    self.all.map {|analysis| [analysis.select_option_display, analysis.select_option_value]}
  end

  # formatted identifer as used in Methods Repository
  def identifier
    "#{self.namespace}/#{self.name}/#{self.snapshot}"
  end

  # formatted configuration identifer as used in Methods Repository
  def configuration_identifier
    "#{self.configuration_namespace}/#{self.configuration_name}/#{self.configuration_snapshot}"
  end

  # analysis identifer as a DOM id (/ replaced with -)
  def dom_identifier
    self.identifier.gsub(/\//, '-')
  end

  # analysis identifer as a select option value (/ replaced with --)
  def select_option_value
    self.identifier.gsub(/\//, '--')
  end

  # display value for dropdown menus in user-facing forms
  def select_option_display
    display_value = self.name
    display_value += self.synopsis.present? ? " (#{self.synopsis})" : nil
    display_value
  end

  # viewable URL for WDL payload in Methods Repository
  def method_repo_url
    "https://portal.firecloud.org/#methods/#{self.identifier}/wdl"
  end

  # viewable URL for WDL configuration in Methods Repository
  def method_repo_config_url
    "https://portal.firecloud.org/#methods/#{self.identifier}/configs/#{self.configuration_identifier}"
  end

  # load input/output parameters directly from Methods Repository
  def methods_repo_settings
    Study.firecloud_client.get_method_parameters(self.namespace, self.name, self.snapshot)
  end

  # get corresponding configuration object from Methods Repository
  def methods_repo_configuration
    Study.firecloud_client.get_configuration(self.configuration_namespace, self.configuration_name, self.configuration_snapshot, true)
  end

  def wdl_payload
    begin
      Study.firecloud_client.get_method(self.namespace, self.name, self.snapshot, true)
    rescue => e
      error_context = ErrorTracker.format_extra_context(self)
      ErrorTracker.report_exception(e, nil, error_context)
      Rails.logger.error "Error retrieving analysis WDL payload for #{self.identifier}: #{e.message}"
      nil
    end
  end

  # get all input/output parameters for this analysis as a hash, can include values if needed
  # this is mainly used for validation purposes. for construction configuration objects for submissions, please
  # use analysis_configuration#configuration_for_repository
  def configuration_settings(include_values=false)
    settings = {}
    self.analysis_parameters.each do |parameter|
      settings[parameter.data_type] ||= []
      config = {
          'name' => "#{parameter.call_name}.#{parameter.parameter_name}"
      }
      if parameter.data_type == 'inputs'
        config.merge!({
                          'optional' => parameter.optional,
                          'inputType' => parameter.parameter_type
                      })
      else
        config.merge!({'outputType' => parameter.parameter_type})
      end
      if include_values
        config['value'] = parameter.parameter_value
      end
      settings[parameter.data_type] << config
    end
    settings
  end

  # get required input configuration (formatted for method inputs/outputs object), can include values if needed
  def required_inputs(include_values=false)
    self.configuration_settings(include_values)['inputs']
  end

  # get required output configuration (formatted for method inputs/outputs object), can include values if needed
  def required_outputs(include_values=false)
    self.configuration_settings(include_values)['outputs']
  end

  # get a hash of all inputs/outputs for this analysis, formatted for the Methods Repository
  def repository_parameter_list(data_type)
    params = {}
    self.analysis_parameters.send(data_type).each do |parameter|
      params["#{parameter.config_param_name}"] = parameter.parameter_value
    end
    params
  end

  # get all the parameter names for a given parameter type
  def analysis_parameter_names(parameter_type)
    self.analysis_parameters.send(parameter_type).map(&:config_param_name)
  end

  # construct a grouped select for analysis parameter names by type
  def param_name_group_opts
    {
        'inputs' => self.analysis_parameter_names(:inputs),
        'outputs' => self.analysis_parameter_names(:outputs)
    }
  end

  # get a hash of the configuration object payload as it would appear in the Methods Repository
  def configuration_for_repository
    {
        "name" => self.configuration_name,
        "namespace" => self.configuration_namespace,
        "methodConfigVersion" => self.configuration_snapshot,
        "methodRepoMethod" => {
            "methodName" => self.name,
            "methodNamespace" => self.namespace,
            "methodVersion" => self.snapshot
        },
        "inputs" => self.repository_parameter_list(:inputs),
        "outputs" => self.repository_parameter_list(:outputs),
        "prerequisites" => {},
        "rootEntityType" => self.entity_type,
        "deleted" => false
    }
  end

  # populate parameters based on user input for submission to a workspace
  def apply_user_inputs(user_inputs, entity_name=nil)
    default_config = self.configuration_for_repository.dup
    user_inputs.each do |parameter_name, parameter_value|
      # cast values to a string, but remove escaped quotes for JSON encoding
      default_config['inputs'][parameter_name] = parameter_value.to_s.gsub(/\\"/, '')
    end
    default_name = default_config['name']
    default_name += entity_name.present? ? "_#{entity_name}" : "_#{SecureRandom.hex(5)}" # make config name unique
    default_config['name'] = default_name
    default_config
  end

  # populate inputs & outputs from analysis WDL definition.  will automatically fire after record creation
  # also clears out any previously saved inputs/outputs, so use with caution!
  # In addition to populating parameters, will also set any default values from configuration
  def load_parameters_from_wdl!
    last_config = {} # keep track for error reporting
    begin
      self.analysis_parameters.delete_all
      config = self.methods_repo_settings
      repo_config = self.methods_repo_configuration
      # set root entity type, if available
      if repo_config['payloadObject'].present? && repo_config['payloadObject']['rootEntityType'].present?
        self.update(entity_type: repo_config['payloadObject']['rootEntityType'])
      end
      config.each do |data_type, settings|
        settings.each do |setting|
          Rails.logger.info "Setting analysis parameter #{data_type}:#{setting['name']} for #{self.identifier}"
          vals = setting['name'].split('.')
          call_name = vals.shift
          parameter_name = vals.join('.')
          parameter_type = data_type == 'inputs' ? setting['inputType'] : setting['outputType']
          optional = setting['optional'] == true
          config_attr = {
              data_type: data_type,
              parameter_type: parameter_type,
              call_name: call_name,
              parameter_name: parameter_name,
              parameter_value: repo_config['payloadObject'][data_type]["#{call_name}.#{parameter_name}"],
              optional: optional
          }
          last_config = config_attr.dup
          unless self.analysis_parameters.where(config_attr).exists?
            self.analysis_parameters.create!(config_attr)
            Rails.logger.info "Analysis parameter #{data_type}:#{setting['name']} for #{self.identifier} successfully set"
          end
        end
      end
      true
    rescue => e
      error_context = ErrorTracker.format_extra_context(self, last_config)
      ErrorTracker.report_exception(e, self.user, error_context)
      Rails.logger.error "Error retrieving analysis WDL inputs/outputs for #{self.identifier}: #{e.message}"
      e
    end
  end

  # set the synopsis from the method repository summary
  def set_synopsis!
    begin
      method = Study.firecloud_client.get_method(self.namespace, self.name, self.snapshot)
      self.update(synopsis: method['synopsis'])
    rescue => e
      error_context = ErrorTracker.format_extra_context(self, last_config)
      ErrorTracker.report_exception(e, self.user, error_context)
      Rails.logger.error "Error retrieving analysis WDL synopsis for #{self.identifier}: #{e.message}"
      e
    end
  end

  private

  # custom presence validator for WDL keys (namespace, name, snapshot) that will halt execution on fail to prevent
  # downstream errors for non-existent attributes
  def ensure_wdl_keys
    [:namespace, :name, :snapshot].each do |attr|
      unless self.send(attr).present?
        errors.add(attr, 'cannot be blank')
      end
    end
    throw(:abort) if self.errors.any?
  end

  # validate that a requested WDL is both accessible and readable
  def validate_wdl_accessibility
    begin
      wdl = Study.firecloud_client.get_method(self.namespace, self.name, self.snapshot)
      if wdl.nil? || wdl['public'] == false
        errors.add(:base, "#{self.identifier} is not viewable by Single Cell Portal.  Please ensure that the analysis WDL is public.")
      end
    rescue => e
      error_context = ErrorTracker.format_extra_context(self)
      ErrorTracker.report_exception(e, self.user, error_context)
      errors.add(:base, "#{self.identifier} is not viewable by Single Cell Portal.  Please ensure that the analysis WDL is public.")
    end
  end

  # validate that a requested WDL has a valid configuration in the methods repo
  def validate_wdl_configuration
    begin
      configuration = Study.firecloud_client.get_configuration(self.configuration_namespace, self.configuration_name, self.configuration_snapshot)
      if configuration.nil? || configuration['public'] == false
        errors.add(:base, "#{self.identifier} does not have a publicly available configuration saved in the Methods Repository")
      end
    rescue => e
      error_context = ErrorTracker.format_extra_context(self)
      ErrorTracker.report_exception(e, self.user, error_context)
      errors.add(:base, "#{self.identifier} does not have a publicly available configuration saved in the Methods Repository")
    end
  end
end
