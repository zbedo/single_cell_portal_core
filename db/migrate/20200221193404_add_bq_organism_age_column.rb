class AddBqOrganismAgeColumn < Mongoid::Migration
  # note this operation is safe to run even if your BQ table already has the given column
  def self.up
    client = BigQueryClient.new.client
    dataset = client.dataset(CellMetadatum::BIGQUERY_DATASET)
    table = dataset.table(CellMetadatum::BIGQUERY_TABLE)
    table.schema {|s| s.numeric('organism_age__seconds', mode: :nullable)}
  end

  def self.down
    # BigQuery does not support column deletions except by dropping and recreating the table,
    # so we'll cross that bridge when/if we come to it
    # See https://cloud.google.com/bigquery/docs/manually-changing-schemas
  end
end
