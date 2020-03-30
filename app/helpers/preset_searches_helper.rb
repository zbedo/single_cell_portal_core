module PresetSearchesHelper

  def facet_query_label(facet_data)
    labels = []
    facet_data[:filters].each do |filter|
      label = "<big><span class='label label-primary' data-toggle='tooltip' title='#{filter[:id]}'>#{facet_data[:id]}: #{filter[:name]}</span></big>"
      labels << label
    end
    labels.join("&nbsp;")
  end
end
