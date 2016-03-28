module ApplicationHelper

	# set gene search placeholder value based on parameters
	def set_search_value
		if params[:search]
			if params[:search][:gene]
				@gene.gene
			elsif !params[:search][:genes].nil?
				@genes.map(&:gene).join(' ')
			end
		elsif params[:gene]
			params[:gene]
		else
			nil
		end
	end

	# create javascript-safe url with parameters
	def javascript_safe_url(url)
		URI.decode(url).html_safe
	end

	# construct nav menu breadcrumbs
	def set_breadcrumbs
		breadcrumbs = []
		if @study
			breadcrumbs << {title: @study.name, link: view_study_path(study_name: @study.url_safe_name)}
		end
		case action_name
			when 'view_gene_expression'
				breadcrumbs << {title: "Gene Expression <span class='badge'>#{params[:gene]}</span>", link: view_gene_expression_path(study_name: @study.name, gene: params[:gene])}
			when 'view_gene_expression_heatmap'
				breadcrumbs << {title: "Gene Expression <span class='badge'>Multiple</span>", link: view_gene_expression_heatmap_path(study_name: @study.name, search: {genes: params[:search][:genes]})}
			when 'view_all_gene_expression_heatmap'
				breadcrumbs << {title: "Gene Expression <span class='badge'>All</span>", link: view_all_gene_expression_heatmap_path(study_name: @study.name)}
		end
		breadcrumbs
	end

	# construct a dropdown for navigating to single gene-level expression views
	def load_gene_nav(genes, cluster=nil)
		nav = [['All queried genes', '']]
		genes.map(&:gene).each do |gene|
			if cluster
				nav << [gene, view_gene_expression_url(study_name: params[:study_name], gene: gene, cluster: cluster)]
			else
				nav << [gene, view_gene_expression_url(study_name: params[:study_name], gene: gene)]
			end
		end
		nav
	end

end
