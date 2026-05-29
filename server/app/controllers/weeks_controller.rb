class WeeksController < ApplicationController
  before_action :require_authentication

  def show
    range = WeekStream.range
    blocks = current_user.blocks.between(range.begin, range.end).chronological.to_a
    @stream = WeekStream.new(blocks)
  end
end
