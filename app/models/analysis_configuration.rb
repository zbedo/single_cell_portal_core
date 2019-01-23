class AnalysisConfiguration
  include Mongoid::Document
  extend ValidationTools
  extend ErrorTracker

  belongs_to :user

  field :namespace, type: String
  field :name, type: String
  field :snapshot, type: Integer
  field :synopsis, type: String

  validate :ensure_wdl_keys
  validates_format_of :namespace, :name, :snapshot, with: ValidationTools::ALPHANUMERIC_DASH,
                      message: ValidationTools::ALPHANUMERIC_DASH_ERROR
  validates_uniqueness_of :name, scope: [:namespace, :snapshot]
  validate :validate_wdl_accessibility

  has_many :analysis_parameters, dependent: :delete
  accepts_nested_attributes_for :analysis_parameters, allow_destroy: true

  after_create :load_parameters_from_wdl!
  after_create :set_synopsis!

  # formatted identifer as used in Methods Repository
  def identifier
    "#{self.namespace}/#{self.name}/#{self.snapshot}"
  end

  # analysis identifer as a DOM id (/ replaced with -)
  def dom_identifier
    self.identifier.gsub(/\//, '-')
  end

  # viewable URL for WDL payload in Methods Repository
  def method_repo_url
    "https://portal.firecloud.org/#methods/#{self.identifier}/wdl"
  end

  # load input/output parameters directly from Methods Repository
  def methods_repo_settings
    Study.firecloud_client.get_method_parameters(self.namespace, self.name, self.snapshot)
  end

  # get all input/output parameters for this analysis as a hash
  def configuration_settings
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
      settings[parameter.data_type] << config
    end
    settings
  end

  # get require input configuration
  def required_inputs
    self.configuration_settings['inputs']
  end

  # get required output configuration
  def required_outputs
    self.configuration_settings['outputs']
  end

  # populate inputs & outputs from reference analysis WDL definition.  will automatically fire after record creation
  # also clears out any previously saved inputs/outputs, so use with caution!
  def load_parameters_from_wdl!
    last_config = {} # keep track for error reporting
    begin
      self.analysis_parameters.delete_all
      config = self.methods_repo_settings
      config.each do |data_type, settings|
        settings.each do |setting|
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
              optional: optional
          }
          last_config = config_attr.dup
          unless self.analysis_parameters.where(config_attr).exists?
            self.analysis_parameters.create!(config_attr)
          end
        end
      end
      true
    rescue => e
      error_context = ErrorTracker.format_extra_context(self, last_config)
      ErrorTracker.report_exception(e, self.user, error_context)
      Rails.logger.error "Error retrieving analysis WDL inputs/outputs: #{e.message}"
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
      Rails.logger.error "Error retrieving analysis WDL synopsis: #{e.message}"
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
      if !wdl['public']
        errors.add(:base, "#{self.identifier} is not viewable by Single Cell Portal.  Please ensure that the analysis WDL is public.")
      end
    rescue => e
      error_context = ErrorTracker.format_extra_context(self)
      ErrorTracker.report_exception(e, self.user, error_context)
      errors.add(:base, "#{self.identifier} is not viewable by Single Cell Portal.  Please ensure that the analysis WDL is public.")
    end
  end

  # validate that a requested WDL has a valid configuration in the methods repo
  def validate_wdl_configurations
    begin
      configurations = Study.firecloud_client.get_method_configurations(self.namespace, self.name, self.snapshot)
      if configurations.empty?
        errors.add(:base, "#{self.identifier} does not have an available configuration saved in the Methods Repository")
      end
    rescue => e
      error_context = ErrorTracker.format_extra_context(self)
      ErrorTracker.report_exception(e, self.user, error_context)
      errors.add(:base, "#{self.identifier} does not have an available configuration saved in the Methods Repository")
    end
  end
end
