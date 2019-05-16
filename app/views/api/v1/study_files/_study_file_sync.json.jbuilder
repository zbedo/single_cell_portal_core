json.set! :name, study_file.name
json.set! :description, study_file.description
json.set! :file_type, study_file.file_type
json.set! :taxon_id, study_file.taxon_id
json.set! :species, study_file.species_name
json.set! :genome_assembly_id, study_file.genome_assembly_id
json.set! :assembly, study_file.genome_assembly_name
json.set! :remote_location, study_file.remote_location
json.set! :human_data, study_file.human_data
json.set! :generation, study_file.generation
json.set! :options, study_file.options
if study_file.persisted?
  json.set! :update_study_file_url, api_v1_study_study_file_url(study_id: @study.id, id: study_file.id)
else
  json.set! :create_study_file_url, api_v1_study_study_files_url(study_id: @study.id)
end
