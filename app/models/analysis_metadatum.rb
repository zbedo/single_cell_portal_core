##
#
# Human Cell Atlas formatted metadata relating to analyses
# https://github.com/HumanCellAtlas/metadata-schema/blob/master/json_schema/analysis.json
#
##

class AnalysisMetadatum
  include Mongoid::Document
  include Mongoid::Timestamps

  # field definitions
  belongs_to :study
  field :payload, type: Hash # actual HCA JSON payload
  field :version, type: String # string version number indicating an HCA release
  field :name, type: String
  field :submission_id, type: String # FireCloud submission ID, also used as internal analysis_id

  ##
  # VALIDATIONS
  ##

  validates_presence_of :payload, :version, :name, :submission_id
  validates_uniqueness_of :submission_id

  ##
  # CONSTANTS
  ##

  # the following constants are hashes of metadata versions with ordered lists of field names to allow mapping
  # to and from HCA- & FireCloud-style names
  HCA_TASK_INFO = {
      '4.6.1' => %w(cpus disk_size docker_image log_err log_out memory name start_time stop_time zone)
  }
  FIRECLOUD_TASK_INFO = {
      '4.6.1' => %w(runtimeAttributes/cpu runtimeAttributes/disks runtimeAttributes/docker stderr stdout runtimeAttributes/memory name start end runtimeAttributes/zones)
  }

  ##
  # INSTANCE METHODS
  ##

  # remote endpoint containing metadata schema
  def definition_url
    "https://raw.githubusercontent.com/HumanCellAtlas/metadata-schema/#{self.version}/json_schema/analysis.json"
  end

  # return a parsed JSON object detailing the metadata schema for this object
  def definition_schema
    begin
      metadata_schema = RestClient.get self.definition_url
      JSON.parse(metadata_schema.body)
    rescue RestClient::ExceptionWithResponse => e
      Rails.logger.error "#{Time.now}: Error retrieving remote HCA Analysis metadata schema: #{e.message}"
      {error: "Error retrieving definition schema: #{e.message}"}
    rescue JSON::ParserError => e
      Rails.logger.error "#{Time.now}: Error parsing remote HCA Analysis metadata schema: #{e.message}"
      {error: "Error parsing definition schema: #{e.message}"}
    end
  end

  # retrieve property or nested field definition information
  # can retrieve info such as require fields, field definitions, property list, etc.
  def definitions(key, field=nil)
    begin
      defs = self.definition_schema[key]
      if field.present?
        defs[field]
      else
        defs
      end
    rescue NoMethodError => e
      field_key = field.present? ? "#{key}/#{field}" : key
      Rails.logger.error "#{Time.now}: Error accessing remote HCA Analysis metadata field definitions for #{field_key}: #{e.message}"
      nil
    end
  end

  # retrieve a mapping of field names between HCA task metadata and FireCloud call metadata
  def task_mapping(type='HCA')
    case type
      when 'HCA'
        Hash[AnalysisMetadatum::HCA_TASK_INFO[self.version].zip(AnalysisMetadatum::FIRECLOUD_TASK_INFO[self.version])]
      when 'FireCloud'
        Hash[AnalysisMetadatum::FIRECLOUD_TASK_INFO[self.version].zip(AnalysisMetadatum::HCA_TASK_INFO[self.version])]
      else
        nil
    end
  end

  # extract call-level metadata from a FireCloud submission to populate task attributes for an analysis
  def get_workflow_call_attributes(submission_id)
    begin
      call_metadata = []
      study = self.study
      # load the instance of the requested workflow
      submission = Study.firecloud_client.get_workspace_submission(study.firecloud_project,
                                                                          study.firecloud_workspace,
                                                                          submission_id)
      submission['workflows'].each do |submission_workflow|
        workflow = Study.firecloud_client.get_workspace_submission_workflow(study.firecloud_project,
                                                                            study.firecloud_workspace,
                                                                            submission_id,
                                                                            submission_workflow['workflowId'])
        # for each 'call', extract the available information as defined by the 'task' definition for this
        # version of the analysis metadatum schema

        workflow['calls'].each do |task, task_attributes|
          call = {
              'name' => task
          }
          # task_attributes is an array of tasks with only one entry
          attributes = task_attributes.first
          # get available definitions and then load the corresponding value in FireCloud call metadata
          # using the HCA_TASK_MAP constant
          self.definitions('definitions','task')['properties'].each do |property, definitions|
            location = self.task_mapping[property]
            # only retrieve value if we have a valid map
            if location.present?
              # some fields are nested, so check first. do a conditional assignment in case we already have a value
              if location.include?('/')
                parent, child = location.split('/')
                call[property] ||= attributes[parent][child]
              else
                call[property] ||= attributes[location]
              end
            else
              # try to do a straight mapping, will likely miss
              Rails.logger.info "#{Time.now}: trying unmappable HCA analysis.task property: #{property}"
              call[property] ||= attributes[property]
              next # we don't know how to map this property yet, so ignore for now but log
            end
          end
          call_metadata << call
        end
      end
      call_metadata
    rescue => e
      Rails.logger.error "#{Time.now}: Error retrieving workflow call metadata for #{submission_id}/#{workflow_id}: #{e.message}"
      []
    end
  end

  # assemble payload object upon completion of a FireCloud submission
  def create_payload
    payload = {}
    study = self.study
    # retrieve submission information
    submission = Study.firecloud_client.get_workspace_submission(study.firecloud_project,
                                                                 study.firecloud_workspace,
                                                                 self.submission_id)
    configuration = Study.firecloud_client.get_workspace_configuration(study.firecloud_project,
                                                                       study.firecloud_workspace,
                                                                       submission['methodConfigurationNamespace'],
                                                                       submission['methodConfigurationName'])
    # retrieve list of properties
    properties = self.definitions('properties')
    properties.each do |prop_name, prop_attr|
      # decide where to pull information based on the property requested
      # TODO: make this more dynamic rather than a hard-coded case statement
      case prop_name
        when 'inputs'
          inputs = []
          configuration['inputs'].each do |name, value|
            inputs << {'name' => name, 'value' => value}
          end
          payload[prop_name] = inputs
        when 'reference_bundle'
          payload[prop_name] = 'https://portal.firecloud.org/#workspaces/single-cell-portal/scp-reference-data'
        when 'tasks'
          payload[prop_name] = self.get_workflow_call_attributes(self.submission_id)
        when 'description'
          method_name = configuration['methodRepoMethod']
          name = "#{method_name['methodNamespace']}/#{method_name['methodName']}/#{method_name['methodVersion']}"
          payload[prop_name] = "Analysis submission of #{name} from Single Cell Portal"
        when 'timestamp_stop_utc'
          payload[prop_name] = Time.now
        when 'input_bundles'
          payload[prop_name] = []
        when 'outputs'
          outputs = []
          submission['workflows'].each do |submission_workflow|
            workflow = Study.firecloud_client.get_workspace_submission_workflow(study.firecloud_project,
                                                                                           study.firecloud_workspace,
                                                                                           submission_id,
                                                                                           submission_workflow['workflowId'])
            outs = workflow['outputs']
            outs.each do |o|
              outputs << {
                  'name' => o.split('/').last,
                  'file_path' => o,
                  'format' => o.split('.').last
              }
            end
          end
          payload[prop_name] = outputs
        when 'name'
          payload[prop_name] = configuration['name']
        when 'computational_method'
          method_name = configuration['methodRepoMethod']
          name = "#{method_name['methodNamespace']}/#{method_name['methodName']}/#{method_name['methodVersion']}"
          method_url = Study.firecloud_client.api_root + "/api/methods/#{name}"
          payload[prop_name] = method_url
        when 'timestamp_start_utc'
          payload[prop_name] = submission['submissionDate']
        when 'core'
          core = {
              'type' => 'analysis',
              'schema_url' => self.definition_url,
              'schema_version' => self.version
          }
          payload[prop_name] = core
        when 'analysis_run_type'
          payload[prop_name] = 'run'
        when 'metadata_schema'
          payload[prop_name] = self.version
        when 'analysis_id'
          payload[prop_name] = "SCP-#{self.submission_id}"
      end
    end
    payload
  end
end
