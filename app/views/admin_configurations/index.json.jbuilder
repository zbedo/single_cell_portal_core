json.array!(@admin_configurations) do |admin_configuration|
  json.extract! admin_configuration, :id, :name, :value
  json.url admin_configuration_url(admin_configuration, format: :json)
end
