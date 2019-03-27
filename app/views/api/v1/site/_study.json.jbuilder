json.set! :accession, study.accession
json.set! :name, study.name
json.set! :description, study.description
json.set! :cell_count, study.cell_count
json.set! :gene_count, study.gene_count
json.study_files study.study_files, partial: 'api/v1/site/study_file', as: :study_file, locals: {study: study}