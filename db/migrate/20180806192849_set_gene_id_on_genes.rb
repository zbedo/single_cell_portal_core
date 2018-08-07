class SetGeneIdOnGenes < Mongoid::Migration
  def self.up
    Gene.delay.add_gene_ids_to_genes # done as a background process to boot portal faster
  end

  def self.down
    Gene.delay.remove_gene_ids_from_genes
  end
end