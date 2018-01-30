class CreateGenesAndCellMetadata < Mongoid::Migration
  def self.up
    ClusterGroup.generate_new_data_arrays
    Gene.generate_new_entries
    CellMetadatum.generate_new_entries
  end

  def self.down
    Gene.delete_all
    CellMetadatum.delete_all
    DataArray.where(:linear_data_type.in => %w(Gene CellMetadatum ClusterGroup Study)).delete_all
  end
end