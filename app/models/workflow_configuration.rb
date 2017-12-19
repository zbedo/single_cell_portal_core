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

          # set workspace information
          Rails.logger.info "#{Time.now}: setting workspace info for #{configuration['name']}"
          configuration['workspaceName'] = {'namespace' => study.firecloud_project, 'name' => study.firecloud_workspace}

          # check if we have created a sample-specific configuration already for this run
          # we need to do this as the input files are hard-coded into the configuration, so we can't overwrite the same
          # configuration continually or concurrent sample submissions will fail
          sample_config_name = configuration_name + "_#{sample_name}"
          existing_configurations = Study.firecloud_client.get_workspace_configurations(study.firecloud_project, study.firecloud_workspace)
          sample_configuration = existing_configurations.find {|config| config['name'] == sample_config_name}
          if sample_configuration.present?
            # overwrite configuration to use current sample values
            configuration['name'] = sample_config_name
            Rails.logger.info "#{Time.now}: overwiting existing sample-specific configuration: #{configuration_namespace}/#{sample_config_name}"
            Study.firecloud_client.overwrite_workspace_configuration(study.firecloud_project, study.firecloud_workspace,
                                                                     sample_configuration['namespace'], sample_configuration['name'],
                                                                     configuration)
          else
            # create new sample-specific configuration
            old_name = configuration['name']
            configuration['name'] = sample_config_name
            Rails.logger.info "#{Time.now}: creating new sample-specific configuration: #{configuration_namespace}/#{sample_config_name}"
            Study.firecloud_client.update_workspace_configuration(study.firecloud_project, study.firecloud_workspace,
                                                                  configuration['namespace'], old_name,
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
      else
        # return immediately as we have no special code to execute for requested workflow
        return response
    end
  end
end