class DashboardController < ApplicationController
  before_action :require_authentication

  def show
    @date = parse_date(params[:date]) || Date.current
    range = @date.beginning_of_day.in_time_zone..@date.end_of_day.in_time_zone
    @day = DayLog.new(current_user.blocks.between(range.begin, range.end).chronological.to_a)
  end

  private

  # Accepts "YYYY-MM-DD"; falls back to nil so the action defaults to today.
  def parse_date(value)
    return nil if value.blank?
    return nil unless value =~ /\A\d{4}-\d{2}-\d{2}\z/

    Date.parse(value)
  rescue ArgumentError
    nil
  end
end
