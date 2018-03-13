##
#
# WorkflowConfiguration: extensible class to take inputs from a user and update an existing workspace configuration with
# workflow-specific parameters
#
# @param: study (Study) => instance of Study class
# @param: configuration_namespace (String) => namespace of selected configuration
# @param: configuration_name (String) => name of selected configuration
# @param: workflow_namespace (String) => namespace of selected workflow
# @param: workflow_name (String) => name of selected workflow
# @param: inputs (Hash) => Hash of input parameters, including sample and other required/optional inputs
#
# @return: response (Hash) => Hash containing completion status and updated configuration attributes (if needed) or error messages (if present)
##

class WorkflowConfiguration < Struct.new(:study, :configuration_namespace, :configuration_name, :workflow_namespace, :workflow_name, :inputs)
  def perform
    # load requested configuration
    configuration = Study.firecloud_client.get_workspace_configuration(study.firecloud_project, study.firecloud_workspace,
                                                                       configuration_namespace, configuration_name)
    # get the requested sample attributes
    sample_name = inputs[:sample_name]

    # pre-load response object
    response = {
        complete: false,
        sample: sample_name,
        configuration_name: configuration_name,
        configuration_namespace: configuration_namespace
    }
    # create an identifier on which to branch
    workflow_identifier = [workflow_namespace, workflow_name].join('-')

    case workflow_identifier
      when /cell-ranger-2-0-2/
        # configure a CellRanger run using the public regev/cell_ranger_2.0.2_count WDL
        begin
          # configure response sample
          response[:sample] = sample_name

          # get workspace sample attributes
          Rails.logger.info "#{Time.now}: getting workspace sample in #{study.firecloud_project}/#{study.firecloud_workspace}"
          workspace_sample = Study.firecloud_client.get_workspace_entity(study.firecloud_project, study.firecloud_workspace,
                                                                         'sample', sample_name)
          input_files = []
          workspace_sample['attributes'].sort_by {|key, value| key}.each do |attribute, value|
            if attribute =~ /fastq_file/
              input_files << value
            end
          end
          Rails.logger.info "#{Time.now}: updating config inputs for #{configuration['name']}"

          # add input files (must cast as string for JSON encoding to work properly)
          configuration['inputs']['cellranger.fastqs'] = input_files.to_s

          # set reference transcriptome (will default to mouse, so only matters if user selects human)
          reference_workspace = AdminConfiguration.find_by(config_type: 'Reference Data Workspace')
          ref_namespace, ref_workspace = reference_workspace.value.split('/')
          reference_attributes = Study.firecloud_client.get_workspace(ref_namespace, ref_workspace)['workspace']['attributes']
          case inputs['transcriptomeTarGz']
            when 'GRCh38'
              configuration['inputs']['cellranger.transcriptomeTarGz'] = "\"#{reference_attributes['cell_ranger_human_ref']}\""
            when 'mm10'
              configuration['inputs']['cellranger.transcriptomeTarGz'] = "\"#{reference_attributes['cell_ranger_mouse_ref']}\""
            else
              configuration['inputs']['cellranger.transcriptomeTarGz'] = "\"#{reference_attributes['cell_ranger_mouse_ref']}\""
          end

          # set the referenceName (configures the links to output files) - this is passed in as the genome assembly name/ID
          configuration['inputs']['cellranger.referenceName'] = "\"#{inputs['transcriptomeTarGz']}\""

          # add optional parameters
          configuration['inputs']['cellranger.expectCells'] = inputs['expectCells']
          configuration['inputs']['cellranger.secondary'] = inputs['secondary']

          # set workspace information
          Rails.logger.info "#{Time.now}: setting workspace info for #{configuration['name']}"
          configuration['workspaceName'] = {'namespace' => study.firecloud_project, 'name' => study.firecloud_workspace}

          # to avoid continually appending sample name to the end of the configuration name, check to make sure it's not already there
          sample_config_name = configuration_name
          if !sample_config_name.end_with?(sample_name)
            sample_config_name += "_#{sample_name}"
          end
          configuration['name'] = sample_config_name
          # determine if we need to create a new configuration object to use for this submission
          configs = Study.firecloud_client.get_workspace_configurations(study.firecloud_project, study.firecloud_workspace)
          matching_conf = configs.detect {|conf| conf['methodRepoMethod'] == configuration['methodRepoMethod'] && conf['name'] == sample_config_name}
          if matching_conf.present?
            existing_configuration = Study.firecloud_client.get_workspace_configuration(study.firecloud_project, study.firecloud_workspace,
                                                                                        matching_conf['namespace'], matching_conf['name'])
            if configuration['inputs'] != existing_configuration['inputs']
              # append an incrementing integer on the end to make this unique, but only if there is an match on the configuration name
              # this may be the very first time this has been launched, in which case we don't have a sample-specific config yet
              num_configs = configs.keep_if {|c| c['methodRepoMethod'] == configuration['methodRepoMethod'] && c['name'] =~ /#{sample_config_name}/}.size
              if num_configs > 0
                sample_config_name += "_#{num_configs + 1}"
              end
              configuration['name'] = sample_config_name
              Rails.logger.info "#{Time.now}: incrementing new sample-specific configuration: #{configuration_namespace}/#{sample_config_name}"
              Study.firecloud_client.create_workspace_configuration(study.firecloud_project, study.firecloud_workspace,
                                                                    configuration)
            else
              Rails.logger.info "#{Time.now}: Found existing matching sample-specific configuration for #{sample_config_name}"
            end
          else
            Rails.logger.info "#{Time.now}: creating new sample-specific configuration: #{configuration_namespace}/#{sample_config_name}"
            Study.firecloud_client.create_workspace_configuration(study.firecloud_project, study.firecloud_workspace,
                                                                  configuration)
          end

          # update response
          response[:configuration_name] = sample_config_name
          response[:complete] = true
          return response
        rescue => e
            Rails.logger.info "#{Time.now}: Error in configuring #{configuration_namespace}/#{configuration_name} using #{inputs}: #{e.message}"
            response[:error_message] = e.message
            return response
        end
      when /SS2_scRNA_pipeline/
        # GP-TAG/SS2_scRNA_pipeline (smart-seq2)

      else
        # return immediately as we have no special code to execute for requested workflow
        Rails.logger.info "#{Time.now}: No extra configuration present for #{configuration_namespace}/#{configuration_name}; exiting"
        response[:complete] = true
        return response
    end
  end

  # load additional parameters for a requested workflow (curated list)
  def self.get_additional_parameters(workflow_identifier)
    opts = {}
    case workflow_identifier
      when /cell-ranger-2-0-2/
        opts.merge!(
             'transcriptomeTarGz' => {
                 type: 'select',
                 default: 'mm10',
                 values: [
                     ['human (GRCh38)', 'GRCh38'],
                     ['mouse (mm10)', 'mm10'],
                 ],
                 required: true,
                 help: 'Cell Ranger compatible transcriptome (human or mouse)'
             },
             'expectCells' => {
                 type: 'integer',
                 default: 3000,
                 required: false,
                 help: 'Expected number of recovered cells. Default: 3,000 cells.'
             },
             'secondary' => {
                 type: 'boolean',
                 default: 'true',
                 required: false,
                 help: 'Set to false to skip secondary analysis of the gene-barcode matrix (dimensionality reduction, clustering and visualization).'
             }
        )
    end
    opts
  end

  # retrieve configuration values for use in HCA metadata
  def self.get_reference_bundle(configuration)
    case configuration['methodRepoMethod']['methodName']
      when /cell.*ranger/
        configuration['inputs']['cellranger.transcriptomeTarGz'].gsub(/\"/, '')
      else
        # fallback to see if we can find anything that might be a 'reference'
        input = configuration['inputs'].detect {|k,v| k =~ /(reference|genome)/}
        if input.present?
          input.last.gsub(/\"/, '')
        end
    end
  end
end