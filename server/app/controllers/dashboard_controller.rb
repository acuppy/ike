class DashboardController < ApplicationController
  before_action :require_authentication

  def show
    blocks = current_user.blocks.between(Time.zone.now.beginning_of_day, Time.zone.now.end_of_day).chronological
    @day = DayLog.new(blocks.to_a)
  end
end
