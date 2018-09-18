module Api
  module V1
    class TaxonsController < ApiBaseController

      # GET /single_cell/api/v1/taxons/:study_id
      def index
        @taxons = Taxon.all
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

