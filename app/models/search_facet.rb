class SearchFacet
  include Mongoid::Document
  include Mongoid::Timestamps

  extend ErrorTracker

  field :name, type: String
  field :filters, type: Array, default: []
  field :is_ontology_based, type: Boolean, default: false
  field :is_array_based, type: Boolean
  field :big_query_id_column, type: String
  field :big_query_name_column, type: String
  field :convention_name, type: String
  field :convention_version, type: String

  validates_presence_of :name, :big_query_id_column, :big_query_name_column, :convention_name, :convention_version
  validates_uniqueness_of :big_query_id_column, scope: [:convention_name, :convention_version]
  before_create :set_is_array_based, unless: proc {|attributes| attributes[:is_array_based].present?}

  def self.big_query_dataset
    ApplicationController.big_query_client.dataset(CellMetadatum::BIGQUERY_DATASET)
  end

  # retrieve table schema definition
  def self.get_table_schema(table_name: CellMetadatum::BIGQUERY_TABLE, column_name: nil)
    begin
      query_string = "SELECT column_name, data_type, is_nullable FROM INFORMATION_SCHEMA.COLUMNS WHERE table_name='#{table_name}'"
      schema = self.big_query_dataset.query(query_string)
      if column_name.present?
        schema.detect {|column| column[:column_name] == column_name}
      else
        schema
      end
    rescue => e
      Rails.logger.error "Error retrieving table schema for #{CellMetadatum::BIGQUERY_TABLE}: #{e.class.name}:#{e.message}"
      error_context = ErrorTracker.format_extra_context({query_string: query_string})
      ErrorTracker.report_exception(e, nil, error_context)
      []
    end
  end

  # return a formatted object to use to render
  def facet_config
    {
        name: self.name,
        filters: self.filters
    }
  end

  # retrieve unique values from BigQuery and format an array of hashes with :name and :id values to populate :filters attribute
  def get_unique_filter_values
    Rails.logger.info "Updating filter values for SearchFacet: #{self.name} using id: #{self.big_query_id_column} and name: #{self.big_query_name_column}"
    # generate DISTINCT sub-query strings for each column
    subqueries = {self.big_query_id_column => "", self.big_query_name_column => ""}
    subqueries.each_key do |bq_col|
      subqueries[bq_col] = self.generate_distinct_sub_query(bq_col)
    end
    query_string = "SELECT DISTINCT #{subqueries[self.big_query_id_column]} as id, #{subqueries[self.big_query_name_column]} as name FROM #{CellMetadatum::BIGQUERY_TABLE}"
    begin
      SearchFacet.big_query_dataset.query(query_string)
    rescue => e
      Rails.logger.error "Error retrieving unique values for #{CellMetadatum::BIGQUERY_TABLE}: #{e.class.name}:#{e.message}"
      error_context = ErrorTracker.format_extra_context({query_string: query_string})
      ErrorTracker.report_exception(e, nil, error_context)
      []
    end
  end

  # update cached filters in place with new values
  def update_filter_values!
    values = self.get_unique_filter_values.to_a
    unless values.empty?
      self.update(filters: values)
    else
      false # did not get any results back, meaning :retrieve_unique_filter_values encountered an error
    end
  end

  # generate a sub-query string to use when trying to extract DISTINCT values from a column
  # depends on whether column is array-based, which requires calling UNNEST()
  # otherwise, sub-query is simply the column name as we can call DISTINCT on non-array columns
  def generate_distinct_sub_query(column_name)
    if self.is_array_based
      "(SELECT * FROM UNNEST(#{column_name}))"
    else
      column_name
    end
  end

  private

  # determine if this facet references array-based data in BQ as data_type will look like "ARRAY<STRING>"
  def set_is_array_based
    column_schema = SearchFacet.get_table_schema(column_name: self.big_query_id_column)
    self.is_array_based = column_schema[:data_type].include?('ARRAY')
  end
end
