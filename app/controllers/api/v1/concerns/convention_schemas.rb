module Api
  module V1
    module Concerns
      module ConventionSchemas
        extend ActiveSupport::Concern

        SCHEMAS_BASE_DIR = Rails.root.join('lib', 'assets', 'metadata_schemas')

        # load available metadata convention schemas from libdir
        def set_available_schemas
          schemas = {}
          projects = Dir.entries(SCHEMAS_BASE_DIR).delete_if {|entry| entry.start_with?('.')}
          projects.each do |project_name|
            snapshots_path = SCHEMAS_BASE_DIR + "#{project_name}/snapshot"
            snapshots = Dir.entries(snapshots_path).delete_if {|entry| entry.start_with?('.')}
            versions = %w(latest) + Naturally.sort(snapshots).reverse
            schemas[project_name] = versions
          end
          schemas
        end
      end
    end
  end
end
