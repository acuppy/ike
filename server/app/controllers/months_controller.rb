class MonthsController < ApplicationController
  before_action :require_authentication

  def show
    target = parse_month(params[:date]) || Date.current.beginning_of_month
    range = MonthLog.grid_range(target)
    blocks = current_user.blocks.between(range.begin, range.end).chronological.to_a
    @month = MonthLog.new(blocks, month: target)
  end

  private

  # Accepts "YYYY-MM"; anything else falls back to nil so the action defaults
  # to the current month.
  def parse_month(value)
    return nil if value.blank?
    return nil unless value =~ /\A\d{4}-\d{2}\z/

    Date.parse("#{value}-01")
  rescue ArgumentError
    nil
  end
end
