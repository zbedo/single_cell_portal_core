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
      when /regev.*cell_ranger_2\.0\.2/
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

          # add optional parameters
          configuration['inputs']['cellranger.expectCells'] = inputs['expectCells']
          configuration['inputs']['cellranger.secondary'] = inputs['secondary']
          Rails.logger.info "config: #{configuration}"

          # set workspace information
          Rails.logger.info "#{Time.now}: setting workspace info for #{configuration['name']}"
          configuration['workspaceName'] = {'namespace' => study.firecloud_project, 'name' => study.firecloud_workspace}

          # to avoid continually appending sample name to the end of the configuration name, check to make sure it's not already there
          sample_config_name = configuration_name
          if !sample_config_name.end_with?(sample_name)
            sample_config_name += "_#{sample_name}"
          end

          # create or update new sample-specific configuration
          old_name = configuration['name']
          configuration['name'] = sample_config_name
          Rails.logger.info "#{Time.now}: creating new sample-specific configuration: #{configuration_namespace}/#{sample_config_name}"
          Study.firecloud_client.update_workspace_configuration(study.firecloud_project, study.firecloud_workspace,
                                                                configuration['namespace'], old_name,
                                                                configuration)

          # update response
          response[:configuration_name] = sample_config_name
          response[:complete] = true
          return response
        rescue => e
            Rails.logger.info "#{Time.now}: Error in configuring #{configuration_namespace}/#{configuration_name} using #{inputs}: #{e.message}"
            response[:error_message] = e.message
            return response
        end
      else
        # return immediately as we have no special code to execute for requested workflow
        Rails.logger.info "#{Time.now}: No extra configuration present for #{configuration_namespace}/#{configuration_name}; exiting"
        response[:complete] = true
        return response
    end
  end

  # load optional parameters for a requested workflow (curated list)
  def self.get_optional_parameters(workflow_identifier)
    opts = {}
    case workflow_identifier
      when 'regev--cell_ranger_2.0.2_count--15'
        opts.merge!(
             'expectCells' => {
                 type: 'integer',
                 default: 3000,
                 help: 'Expected number of recovered cells. Default: 3,000 cells.'
             },
             'secondary' => {
                 type: 'boolean',
                 default: 'true',
                 help: 'Set to false to skip secondary analysis of the gene-barcode matrix (dimensionality reduction, clustering and visualization).'
             }
        )
    end
    opts
  end
end