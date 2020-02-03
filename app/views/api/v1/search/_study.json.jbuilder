json.set! :accession, study.accession
json.set! :name, study.name
json.set! :description, study.description
json.set! :public, study.public
json.set! :detached, study.detached
json.set! :cell_count, study.cell_count
json.set! :gene_count, study.gene_count
json.set! :study_url, view_study_path(accession: study.accession, study_name: study.url_safe_name)
if @studies_by_facet.present?
  # faceted search was run, so append filter matches
  json.set! :facet_matches, @studies_by_facet[study.accession]
end
if params[:terms].present?
  json.set! :term_matches, params[:terms]
end
if study.detached
  json.set! :study_files, 'Unavailable (cannot load study workspace or bucket)'
else
  json.study_files do
    json.set! :Metadata do
      json.array! study.study_files.by_type('Metadata'), partial: 'api/v1/search/study_file', as: :study_file, locals: {study: study}
    end
    json.set! :Expression do
      json.array! study.study_files.by_type(['Expression Matrix', 'MM Coordinate Matrix']), partial: 'api/v1/search/study_file', as: :study_file, locals: {study: study}
    end
  end
end