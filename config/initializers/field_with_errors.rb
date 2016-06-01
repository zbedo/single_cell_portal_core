ActionView::Base.field_error_proc = Proc.new do |html_tag, instance|
	html = %(<span class="text-danger">#{html_tag}</span>).html_safe
	# add nokogiri gem to Gemfile

	form_fields = %w(textarea input select)

	elements = Nokogiri::HTML::DocumentFragment.parse(html_tag).css "label, " + form_fields.join(', ')

	elements.each do |e|
		if form_fields.include? e.node_name
			html = %(<div class="has-error">#{html_tag}</div>).html_safe
		end
	end
	html
end