module StudiesHelper
	def get_boolean_label(field)
		field ? "<span class='fa fa-check text-success'></span>".html_safe : "<span class='fa fa-times text-danger'></span>".html_safe
	end

	def get_na_label
		"<span class='label label-default'><i class='fa fa-ban' aria-hidden='true'></i> N/A</span>".html_safe
	end

	def get_site_path_with_params(search_val, order_val)
		if search_val.blank?
			site_path(order: order_val)
		else
			site_path(order: order_val, search_terms: search_val)
		end
	end
end