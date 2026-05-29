# N most-recent Sun-Sat weeks as a list of WeekLogs, newest first. Lets the
# Weekly Trends page scroll back through history one week at a time.
class WeekStream
  DEFAULT_COUNT = 12

  attr_reader :weeks

  def initialize(blocks, count: DEFAULT_COUNT, reference_date: Date.current)
    @blocks = blocks
    @count = count
    @reference_date = reference_date.to_date
    @weeks = build_weeks
  end

  # The blocks range a controller should fetch to populate `count` Sun-Sat
  # weeks ending in the current week of `reference_date`.
  def self.range(count: DEFAULT_COUNT, reference_date: Date.current)
    current_sunday = reference_date.to_date.beginning_of_week(:sunday)
    earliest_sunday = current_sunday - (count - 1).weeks
    earliest_sunday.beginning_of_day.in_time_zone..(current_sunday + 6.days).end_of_day.in_time_zone
  end

  private

  def build_weeks
    current_sunday = @reference_date.beginning_of_week(:sunday)
    by_week_start = @blocks.group_by { |b| b.starts_at.in_time_zone.to_date.beginning_of_week(:sunday) }

    Array.new(@count) do |i|
      sunday = current_sunday - i.weeks
      WeekLog.new(by_week_start[sunday] || [], start_date: sunday)
    end
  end
end
