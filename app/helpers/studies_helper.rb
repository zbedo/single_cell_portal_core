module StudiesHelper
	def get_boolean_label(field)
		field ? "<span class='fa fa-check text-success'></span>".html_safe : "<span class='fa fa-times text-danger'></span>".html_safe
	end
end
