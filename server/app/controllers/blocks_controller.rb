class BlocksController < ApplicationController
  before_action :require_authentication
  before_action :set_block, only: [:edit, :update, :destroy]

  # All activity, newest first, grouped by day in the view.
  def index
    @blocks = current_user.blocks.recent_first
  end

  def edit
  end

  def update
    if @block.update(block_params)
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace(@block, partial: "blocks/block", locals: { block: @block }) }
        format.html { redirect_to blocks_path, notice: "Block updated" }
      end
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @block.destroy
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.remove(@block) }
      format.html { redirect_to blocks_path, notice: "Block deleted" }
    end
  end

  private

  def set_block
    @block = current_user.blocks.find(params[:id])
  end

  def block_params
    params.require(:block).permit(:quadrant, :note)
  end
end
