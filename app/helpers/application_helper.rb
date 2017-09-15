module ApplicationHelper

	# set gene search placeholder value based on parameters
	def set_search_value
		if params[:search]
			if params[:search][:gene]
				@gene
			elsif !params[:search][:genes].nil?
				@genes.map{|gene| gene['gene']}
			end
		elsif params[:gene]
			params[:gene]
		else
			nil
		end
	end

	# create javascript-safe url with parameters
	def javascript_safe_url(url)
		# remove utf8=✓& from url to avoid formatting errors
		URI.decode(url.gsub(/utf8=%E2%9C%93&/, '')).html_safe
	end

	# construct nav menu breadcrumbs
	def set_breadcrumbs
		breadcrumbs = []
		if controller_name == 'site'
			if @study
				breadcrumbs << {title: "Study Overview", link: view_study_path(study_name: @study.url_safe_name)}
			end
			case action_name
				when 'view_gene_expression'
					breadcrumbs << {title: "Gene Expression <span class='badge'>#{params[:gene]}</span>", link: 'javascript:;'}
				when 'view_gene_set_expression'
					breadcrumbs << {title: "Gene Set Expression <span class='badge'>Multiple</span>", link: 'javascript:;'}
				when 'view_gene_expression_heatmap'
					breadcrumbs << {title: "Gene Expression <span class='badge'>Multiple</span>", link: 'javascript:;'}
				when 'view_precomputed_gene_expression_heatmap'
					breadcrumbs << {title: "Gene Expression <span class='badge'>#{params[:precomputed]}</span>", link: 'javascript:;'}
				when 'view_all_gene_expression_heatmap'
					breadcrumbs << {title: "Gene Expression <span class='badge'>All</span>", link: 'javascript:;'}
			end
		elsif controller_name == 'studies'
			breadcrumbs << {title: "My Studies", link: studies_path}
			case action_name
				when 'new'
					breadcrumbs << {title: "New Study", link: 'javascript:;'}
				when 'edit'
					breadcrumbs << {title: "Editing '#{truncate(@study.name, length: 20)}'", link: 'javascript:;'}
				when 'show'
					breadcrumbs << {title: "Showing '#{truncate(@study.name, length: 20)}'", link: 'javascript:;'}
				when 'initialize_study'
					breadcrumbs << {title: "Upload/Edit Study Data", link: 'javascript:;'}
				when 'sync_study'
					breadcrumbs << {title: "Synchronize Workspace", link: 'javascript:;'}
			end
		elsif controller_name == 'admin_configurations'
			breadcrumbs << {title: 'Admin Control Panel', link: admin_configurations_path}
			case action_name
				when 'new'
					breadcrumbs << {title: "New Config Option", link: 'javascript:;'}
				when 'edit'
					breadcrumbs << {title: "Editing '#{@admin_configuration.config_type}'", link: 'javascript:;'}
			end
		end
		breadcrumbs
	end

	# construct a dropdown for navigating to single gene-level expression views
	def load_gene_nav(genes)
		nav = [['All queried genes', '']]
		genes.each do |gene|
			nav << [gene['gene'], view_gene_expression_path(study_name: params[:study_name], gene: gene['gene'])]
		end
		nav
	end

	# method to set cluster value based on options and parameters
	# will fall back to default cluster if nothing is specified
	def set_cluster_value(selected_study, parameters)
		if !parameters[:gene_set_cluster].nil?
			parameters[:gene_set_cluster]
		elsif !parameters[:cluster].nil?
			parameters[:cluster]
		else
			selected_study.default_cluster.name
		end
	end

	# method to set annotation value by parameters or load a 'default' annotation when first loading a study (none have been selected yet)
	# will fall back to default annotation if nothing is specified
	def set_annotation_value(selected_study, parameters)
		if !parameters[:gene_set_annotation].nil?
			parameters[:gene_set_annotation]
		elsif !parameters[:annotation].nil?
			parameters[:annotation]
		else
			selected_study.default_annotation
		end
	end

	# method to set annotation value by parameters or load a 'default' annotation when first loading a study (none have been selected yet)
	# will fall back to default annotation if nothing is specified
	def set_subsample_value(parameters)
		if !parameters[:gene_set_subsample].nil?
			parameters[:gene_set_subsample].to_i
		elsif !parameters[:subsample].nil?
			parameters[:subsample].to_i
		else
			'All Cells'
		end
	end

	# set colorscale value
	def set_colorscale_value(selected_study, parameters)
		if !parameters[:colorscale].nil?
			parameters[:colorscale]
		elsif selected_study.default_cluster.name == parameters[:cluster] && !selected_study.default_color_profile.nil?
			selected_study.default_color_profile
		else
			'Reds'
		end
	end

	# return an array of values to use for subsampling dropdown scaled to number of cells in study
	# only options allowed are 1000, 10000, 20000
	def subsampling_options(max_cells)
		ClusterGroup::SUBSAMPLE_THRESHOLDS.select {|sample| sample < max_cells}
	end

	# get a label for a workflow status code
	def submission_status_label(status)
		case status
			when 'Queued'
				label_class = 'default'
			when 'Submitted'
				label_class = 'info'
			when 'Running'
				label_class = 'primary'
			when 'Done'
				label_class = 'success'
			when 'Aborting'
				label_class = 'warning'
			when 'Aborted'
				label_class = 'danger'
			else
				label_class = 'default'
		end
		"<span class='label label-#{label_class}'>#{status}</span>".html_safe
	end

	# get a label for a workflow status code
	def workflow_status_labels(workflow_statuses)
		labels = []
		workflow_statuses.keys.each do |status|
			case status
				when 'Submitted'
					label_class = 'info'
				when 'Launching'
					label_class = 'info'
				when 'Running'
					label_class = 'primary'
				when 'Succeeded'
					label_class = 'success'
				when 'Failed'
					label_class = 'danger'
				else
					label_class = 'default'
			end
			labels << "<span class='label label-#{label_class}'>#{status}</span>"
		end
		labels.join("<br />").html_safe
	end

	# get a UTC timestamp in local time, formatted all purty-like
	def local_timestamp(utc_time)
		Time.zone.parse(utc_time).strftime("%F %R")
	end

	# get actions links for a workflow submission
	def get_submission_actions(submission, study)
		actions = []
		# submission is still queued or running
		if %w(Queued Submitted Running).include?(submission['status'])
			actions << link_to("<i class='fa fa-times'></i> Abort".html_safe, '#', class: 'btn btn-xs btn-block btn-danger abort-submission', title: 'Stop execution of this workflow', data: {toggle: 'tooltip', url: abort_submission_workflow_path(study_name: study.url_safe_name, submission_id: submission['submissionId']), id: submission['submissionId']})
		end
		# submission has completed successfully
		if submission['status'] == 'Done' && submission['workflowStatuses'].keys.include?('Succeeded')
			actions << link_to("<i class='fa fa-files-o'></i> Download".html_safe, '#', class: 'btn btn-xs btn-block btn-primary get-submission-outputs', title: 'Download outputs from this run', data: {toggle: 'tooltip', url: get_submission_outputs_path(study_name: study.url_safe_name, submission_id: submission['submissionId']), id: submission['submissionId']})
			actions << link_to("<i class='fa fa-refresh'></i> Sync".html_safe, sync_submission_outputs_study_path(id: @study.id, submission_id: submission['submissionId']), class: 'btn btn-xs btn-block btn-warning sync-submission-outputs', title: 'Sync outputs from this run back to study', data: {toggle: 'tooltip', id: submission['submissionId']})
		end
		# submission has failed
		if %w(Done Aborted).include?(submission['status']) && submission['workflowStatuses'].keys.include?('Failed')
			actions << link_to("<i class='fa fa-exclamation-triangle'></i> Show Errors".html_safe, '#', class: 'btn btn-xs btn-block btn-danger get-submission-errors', title: 'View errors for this run', data: {toggle: 'tooltip', url: get_submission_workflow_path(study_name: study.url_safe_name, submission_id: submission['submissionId']), id: submission['submissionId']})
		end
		# delete action to always load when completed
		if %w(Done Aborted).include?(submission['status'])
			actions << link_to("<i class='fa fa-trash'></i> Delete Submission".html_safe, '#', class: 'btn btn-xs btn-block btn-danger delete-submission-files', title: 'Remove submission from list and delete all files from submission directory', data: {toggle: 'tooltip', url: delete_submission_files_path(study_name: study.url_safe_name, submission_id: submission['submissionId']), id: submission['submissionId']})
		end
		actions.join(" ").html_safe
	end
end
