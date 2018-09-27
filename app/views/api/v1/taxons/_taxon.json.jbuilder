json.(taxon, :id, :common_name, :scientific_name, :ncbi_taxid, :aliases, :notes)
json.genome_assemblies taxon.genome_assemblies, partial: 'api/v1/taxons/genome_assembly', as: :genome_assembly
