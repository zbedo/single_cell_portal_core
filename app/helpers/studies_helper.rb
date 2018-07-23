module StudiesHelper
  # formatted label for boolean values
	def get_boolean_label(field)
		field ? "<span class='fas fa-check text-success'></span>".html_safe : "<span class='fas fa-times text-danger'></span>".html_safe
	end

  # formatted label for parse status of uploaded files
	def get_parse_label(parse_status)
		case parse_status
			when 'unparsed'
				"<span class='fas fa-times text-danger' title='Unparsed' data-toggle='tooltip'></span>".html_safe
			when 'parsing'
				"<span class='fas fa-sync-alt text-warning' title='Parsing' data-toggle='tooltip'></span>".html_safe
			when 'parsed'
				"<span class='fas fa-check text-success' title='Parsed' data-toggle='tooltip'></span>".html_safe
			else
				"<span class='fas fa-times text-danger' title='Unparsed' data-toggle='tooltip'></span>".html_safe
		end
	end

  # formatted label for NA values
	def get_na_label
		"<span class='label label-default'><i class='fas fa-ban' aria-hidden='true'></i> N/A</span>".html_safe
	end

  # return formatted path with parameters for main site_path url
	def get_site_path_with_params(search_val, order_val)
		if search_val.blank?
			site_path(order: order_val)
		else
			site_path(order: order_val, search_terms: search_val)
		end
	end
end