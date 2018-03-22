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
# @param: inputs (Hash) => Hash of input parameters, including sample and other additional inputs
#
# @return: response (Hash) => Hash containing completion status and updated configuration attributes (if needed) or error messages (if present)
##

class WorkflowConfiguration < Struct.new(:study, :configuration_namespace, :configuration_name, :workflow_namespace, :workflow_name, :inputs)
  # update a FireCloud configuration with run-specific information
  def perform
    begin
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

      Rails.logger.info "#{Time.now}: updating config inputs for #{configuration['name']}"

      case workflow_identifier
        when /cell-ranger-2-0-2/
          # configure a CellRanger run using the public regev/cell_ranger_2.0.2_count WDL
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
          case inputs['cellranger']['transcriptomeTarGz']
            when 'GRCh38'
              configuration['inputs']['cellranger.transcriptomeTarGz'] = "\"#{reference_attributes['cell_ranger_human_ref']}\""
            when 'mm10'
              configuration['inputs']['cellranger.transcriptomeTarGz'] = "\"#{reference_attributes['cell_ranger_mouse_ref']}\""
            else
              configuration['inputs']['cellranger.transcriptomeTarGz'] = "\"#{reference_attributes['cell_ranger_mouse_ref']}\""
          end

          # set the referenceName (configures the links to output files) - this is passed in as the genome assembly name/ID
          configuration['inputs']['cellranger.referenceName'] = "\"#{inputs['cellranger']['transcriptomeTarGz']}\""

          # add optional parameters
          configuration['inputs']['cellranger.expectCells'] = inputs['cellranger']['expectCells']
          configuration['inputs']['cellranger.secondary'] = inputs['cellranger']['secondary']

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
          configuration = self.update_workspace_config(configuration, sample_config_name)
          # update response
          response[:configuration_name] = configuration['name']
        when /SS2_scRNA_pipeline/ # GP-TAG/SS2_scRNA_pipeline (smart-seq2)
          # set additional inputs
          configuration['inputs']['SmartSeq2SingleCell.stranded'] = "\"#{inputs['SmartSeq2SingleCell']['stranded']}\""
        when /inferCNV/ # InferCNV analysis
          # get reference data workspace attributes
          reference_workspace = AdminConfiguration.find_by(config_type: 'Reference Data Workspace')
          ref_namespace, ref_workspace = reference_workspace.value.split('/')
          reference_attributes = Study.firecloud_client.get_workspace(ref_namespace, ref_workspace)['workspace']['attributes']
          # set the gene position file
          case inputs['cellranger']['transcriptomeTarGz']
            when 'GRCh38'
              configuration['inputs']['infercnv.gen_pos_file'] = "\"#{reference_attributes['infercnv_human_gen_pos_file']}\""
            when 'mm10'
              configuration['inputs']['infercnv.gen_pos_file'] = "\"#{reference_attributes['infercnv_mouse_gen_pos_file']}\""
            else
              configuration['inputs']['infercnv.gen_pos_file'] = "\"#{reference_attributes['infercnv_mouse_gen_pos_file']}\""
          end

          # assemble cluster information
          cluster_files = []
          cluster_names = []
          study.cluster_groups.each do |cluster|
            cluster_names << cluster.name
            cluster_files << StudyFile.find(cluster.study_file_id).gs_url
          end
          configuration['inputs']['infercnv.cluster_names'] = cluster_names
          configuration['inputs']['infercnv.cluster_paths'] = cluster_files

          # assign expression file to configuration
          configuration['inputs']['infercnv.expression_file'] = inputs['expression_file']
          # update name to include name of expression file
          exp_file_name = configuration['inputs']['infercnv.expression_file'].split('/').last.split('.').first
          exp_config_name = configuration_name + "_#{exp_file_name}"
          configuration = self.update_workspace_config(configuration, exp_config_name)
          response[:configuration_name] = configuration['name']
        else
          # return immediately as we have no special code to execute for requested workflow
          Rails.logger.info "#{Time.now}: No extra configuration present for #{configuration_namespace}/#{configuration_name}; exiting"
      end

      # update response object and return
      response[:complete] = true
      return response
    rescue => e
      # generic error catch all, will halt workflow submission and return error message to UI
      Rails.logger.error "#{Time.now}: Error in configuring #{configuration_namespace}/#{configuration_name} using #{inputs}: #{e.message}"
      response[:error_message] = e.message
      return response
    end
  end

  # determine whether or not we need to create a new input-specific configuration object in the study's workspace for
  # this submission instance
  def update_workspace_config(configuration, current_name)
    configs = Study.firecloud_client.get_workspace_configurations(study.firecloud_project, study.firecloud_workspace)
    matching_conf = configs.detect {|conf| conf['methodRepoMethod'] == configuration['methodRepoMethod'] && conf['name'] == current_name}
    if matching_conf.present?
      existing_configuration = Study.firecloud_client.get_workspace_configuration(study.firecloud_project, study.firecloud_workspace,
                                                                                  matching_conf['namespace'], matching_conf['name'])
      if configuration['inputs'] != existing_configuration['inputs']
        # append an incrementing integer on the end to make this unique, but only if there is an match on the configuration name
        # this may be the very first time this has been launched, in which case we don't have a sample-specific config yet
        num_configs = configs.keep_if {|c| c['methodRepoMethod'] == configuration['methodRepoMethod'] && c['name'] =~ /#{current_name}/}.size
        if num_configs > 0
          current_name += "_#{num_configs + 1}"
        end
        configuration['name'] = current_name
        Rails.logger.info "#{Time.now}: incrementing new sample-specific configuration: #{configuration['namespace']}/#{current_name}"
        Study.firecloud_client.create_workspace_configuration(study.firecloud_project, study.firecloud_workspace,
                                                              configuration)
      else
        Rails.logger.info "#{Time.now}: Found existing matching sample-specific configuration for #{current_name}"
      end
    else
      Rails.logger.info "#{Time.now}: creating new sample-specific configuration: #{configuration['namespace']}/#{current_name}"
      Study.firecloud_client.create_workspace_configuration(study.firecloud_project, study.firecloud_workspace,
                                                            configuration)
    end
    # return updated configuration
    configuration
  end

  # return additional parameters for a requested workflow (curated list) to update UI
  def self.get_additional_parameters(workflow_identifier)
    opts = {}
    case workflow_identifier
      when /cell-ranger-2-0-2/
        opts.merge!(
            'cellranger' => {
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
                    help: 'Set to \'No\' to skip secondary analysis of the gene-barcode matrix (dimensionality reduction, clustering and visualization).'
                }
            }
        )
      when /SS2_scRNA_pipeline/
        opts.merge!(
            'SmartSeq2SingleCell' => {
                'stranded' => {
                    type: 'select',
                    default: 'NONE',
                    values: [
                        ['NONE', 'NONE'],
                        ['FIRST_READ_TRANSCRIPTION_STRAND', 'FIRST_READ_TRANSCRIPTION_STRAND'],
                        ['SECOND_READ_TRANSCRIPTION_STRAND', 'SECOND_READ_TRANSCRIPTION_STRAND']
                    ],
                    required: true,
                    help: 'For strand-specific library prep. For unpaired reads, use FIRST_READ_TRANSCRIPTION_STRAND if the reads are expected to be on the transcription strand.'
                }
            }
        )
      when /inferCNV/
        opts.merge!(
            'infercnv' => {
                'gen_pos_file' => {
                    type: 'select',
                    default: 'GRCh38',
                    values: [
                        ['human (GRCh38)', 'GRCh38'],
                        ['mouse (mm10)', 'mm10'],
                    ],
                    required: true,
                    help: 'Gene position annotation source (human or mouse)'
                }
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
      when /SS2_scRNA_pipeline/
        configuration['inputs']['SmartSeq2SingleCell.genome_ref_fasta'].gsub(/\"/, '')
      when /inferCNV/
        configuration['inputs']['infercnv.gen_pos_file'].gsub(/\"/, '')
      else
        # fallback to see if we can find anything that might be a 'reference'
        input = configuration['inputs'].detect {|k,v| k =~ /(reference|genome)/}
        if input.present?
          input.last.gsub(/\"/, '')
        end
    end
  end
end