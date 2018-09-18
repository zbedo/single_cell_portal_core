json.(genome_assembly, :id, :name, :alias, :release_date)
json.genome_annotations genome_assembly.genome_annotations, partial: 'api/v1/taxons/genome_annotation', as: :genome_annotation