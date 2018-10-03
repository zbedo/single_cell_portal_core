module Api
  module V1
    class TaxonsController < ApiBaseController
      include Swagger::Blocks

      swagger_path '/taxons' do
        operation :get do
          key :tags, [
              'Taxons'
          ]
          key :summary, 'List all registered Taxons'
          key :description, 'Returns a list of all registerd Taxons (species) available in the portal'
          key :operationId, 'taxons_path'
          response 200 do
            key :description, 'Array of Taxons'
            schema do
              key :type, :array
              key :title, 'Array'
              items do
                key :title, 'Taxon'
                key :'$ref', :Taxon
              end
            end
          end
        end
      end

      # GET /single_cell/api/v1/taxons/:study_id
      def index
        @taxons = Taxon.all
      end

      swagger_path '/taxons/{id}' do
        operation :get do
          key :tags, [
              'Taxons'
          ]
          key :summary, 'Find a Taxon'
          key :description, 'Finds a single Taxon'
          key :operationId, 'taxon_path'
          parameter do
            key :name, :id
            key :in, :path
            key :description, 'ID of Taxon to fetch'
            key :required, true
            key :type, :string
          end
          response 200 do
            key :description, 'Taxon object'
            schema do
              key :title, 'Taxon'
              key :'$ref', :Taxon
            end
          end
        end
      end
      # GET /single_cell/api/v1/taxons/:id
      def show
        @taxon = Taxon.find(id: params[:id])
        unless @taxon.present?
          head 404
        end
      end
    end
  end
end

