json.set! :accession, study.accession
json.set! :name, study.name
json.set! :description, study.description
json.set! :public, study.public
json.set! :detached, study.detached
json.set! :cell_count, study.cell_count
json.set! :gene_count, study.gene_count
json.set! :study_url, view_study_path(accession: study.accession, study_name: study.url_safe_name) + (params[:scpbr].present? ? "?scpbr=#{params[:scpbr]}" : '')
if @studies_by_facet.present?
  # faceted search was run, so append filter matches
  json.set! :facet_matches, @studies_by_facet[study.accession]
end
if params[:terms].present?
  search_weight = study.search_weight(@term_list)
  json.set! :term_matches, search_weight[:terms].keys
  json.set! :term_search_weight, search_weight[:total]
end
# if this is an inferred match, use :term_matches for highlighting, but set :inferred_match to true
if @inferred_accessions.present? && @inferred_accessions.include?(study.accession)
  json.set! :inferred_match, true
  inferred_weight = study.search_weight(@inferred_terms)
  json.set! :term_matches, inferred_weight[:terms].keys
  json.set! :term_search_weight, inferred_weight[:total]
end
if @preset_search.present? && @preset_search.accession_whitelist.include?(study.accession)
  json.set! :preset_match, true
end
if @gene_results.present?
  json.set! :gene_matches, @gene_results[:genes_by_study][study.id]
end
if study.detached
  json.set! :study_files, 'Unavailable (cannot load study workspace or bucket)'
else
  json.study_files do
    StudyFile::BULK_DOWNLOAD_TYPES.each do |file_category|
      if file_category == 'Expression'
        json.set! :Expression do
          json.array! study.study_files.by_type(['Expression Matrix', 'MM Coordinate Matrix']), partial: 'api/v1/search/study_file', as: :study_file, locals: {study: study}
        end
      else
        json.set! file_category do
          json.array! study.study_files.by_type(file_category), partial: 'api/v1/search/study_file', as: :study_file, locals: {study: study}
        end
      end
    end
  end
end
