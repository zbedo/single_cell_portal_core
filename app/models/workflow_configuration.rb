##
#
# WorkflowConfiguration: extensible class to take inputs from a user and update an existing workspace configuration with
# workflow-specific parameters
#
##

class WorkflowConfiguration < Struct.new(:study, :configuration_namespace, :configuration_name, :workflow_namespace, :workflow_name, :inputs)

  def perform
    # load requested configuration
    configuration = Study.firecloud_client.get_workspace_configuration(study.firecloud_project, study.firecloud_workspace,
                                                                       configuration_namespace, configuration_name)
    # create an identifier on which to branch
    workflow_identifier = [workflow_namespace, workflow_name].join('-')
    case workflow_identifier
      when /regev.*cell_ranger/
        # configure a CellRanger run using the public regev/cell_ranger WDL

        # get the requested sample attributes
        sample_name = inputs[:sample_name]
        Rails.logger.info "#{Time.now} getting workspace sample"
        workspace_sample = Study.firecloud_client.get_workspace_entity(study.firecloud_project, study.firecloud_workspace,
                                                                       'sample', sample_name)
        input_files = []
        workspace_sample['attributes'].sort_by {|key, value| key}.each do |attribute, value|
          if attribute =~ /fastq_file/
            input_files << value
          end
        end
        Rails.logger.info "#{Time.now}: updating config inputs"
        # add input files (must cast as string for JSON encoding to work properly)
        configuration['inputs']['cellranger.fastqs'] = input_files.to_s

        # set workspace information
        Rails.logger.info "#{Time.now}: setting workspace info"
        configuration['workspaceName'] = {'namespace' => study.firecloud_project, 'name' => study.firecloud_workspace}

        # update configuration
        Rails.logger.info "#{Time.now}: updating configuration"
        Study.firecloud_client.overwrite_workspace_configuration(study.firecloud_project, study.firecloud_workspace,
                                                                 configuration['namespace'], configuration['name'],
                                                                 configuration)

      else
        nil # we have no special code to execute for requested workflow
    end
  end
end