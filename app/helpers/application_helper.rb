module ApplicationHelper

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
end
