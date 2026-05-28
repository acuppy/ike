module Api
  module V1
    class BlocksController < BaseController
      # GET /api/v1/blocks?from=ISO8601&to=ISO8601
      def index
        blocks = current_user.blocks.chronological
        blocks = blocks.where(starts_at: parse_time(params[:from])..) if params[:from].present?
        blocks = blocks.where(starts_at: ..parse_time(params[:to])) if params[:to].present?
        render json: blocks.map { |b| serialize(b) }
      end

      # POST /api/v1/blocks
      # Idempotent: a repeated external_id updates the existing block rather
      # than creating a duplicate, so clients can safely retry pushes.
      def create
        block = find_or_initialize_by_external_id
        if block.update(block_params)
          render json: serialize(block), status: block.previously_new_record? ? :created : :ok
        else
          render json: { errors: block.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PATCH /api/v1/blocks/:id
      def update
        block = current_user.blocks.find(params[:id])
        if block.update(block_params)
          render json: serialize(block)
        else
          render json: { errors: block.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/blocks/:id
      def destroy
        current_user.blocks.find(params[:id]).destroy
        head :no_content
      end

      private

      def find_or_initialize_by_external_id
        if params.dig(:block, :external_id).present?
          current_user.blocks.find_or_initialize_by(external_id: params[:block][:external_id])
        else
          current_user.blocks.new
        end
      end

      def block_params
        params.require(:block).permit(:starts_at, :ends_at, :quadrant, :note, :auto, :external_id)
      end

      def parse_time(value)
        Time.zone.parse(value)
      end

      def serialize(block)
        {
          id: block.id,
          external_id: block.external_id,
          starts_at: block.starts_at&.iso8601,
          ends_at: block.ends_at&.iso8601,
          quadrant: block.quadrant,
          note: block.note,
          auto: block.auto
        }
      end
    end
  end
end
