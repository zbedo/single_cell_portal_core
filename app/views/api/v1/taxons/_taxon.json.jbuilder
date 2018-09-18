json.(taxon, :id, :common_name, :scientific_name, :taxon_identifier, :aliases, :notes)
json.genome_assemblies taxon.genome_assemblies, partial: 'api/v1/taxons/genome_assembly', as: :genome_assembly
