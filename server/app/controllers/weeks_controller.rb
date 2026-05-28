class WeeksController < ApplicationController
  before_action :require_authentication

  def show
    from = 6.days.ago.beginning_of_day
    to = Time.zone.now.end_of_day
    @week = WeekLog.new(current_user.blocks.between(from, to).chronological.to_a)
  end
end
