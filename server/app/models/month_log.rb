# A month rendered as a Sunday-first calendar grid. Each Day in the grid
# knows whether it falls in the target month and, if any work was logged,
# the Quadrant the day skewed toward — used to color the cell.
#
# "Majority" excludes break time (same signal as the Today trending banner)
# and ties go to the higher quadrant (Q1 > Q2 > Q3 > Q4) so a 50/50 day
# reads as the more urgent half.
class MonthLog
  Day = Struct.new(:date, :in_month, :majority, :total_seconds, keyword_init: true) do
    def empty?
      total_seconds <= 0
    end

    def has_color?
      majority.present?
    end
  end

  WEEKDAY_LABELS = %w[Sun Mon Tue Wed Thu Fri Sat].freeze

  attr_reader :weeks

  def initialize(blocks, month:)
    @month = month.to_date.beginning_of_month
    @blocks = blocks
    @weeks = build_weeks
  end

  # "2026-05" — used in DOM ids so per-month broadcasts only land on the page
  # actually viewing that month.
  def year_month
    @month.strftime("%Y-%m")
  end

  def label
    @month.strftime("%B %Y")
  end

  def previous_month
    @month - 1.month
  end

  def next_month
    @month + 1.month
  end

  # Range of starts_at that covers every cell in the visible grid (so a
  # controller can fetch exactly the blocks the view will reference).
  def self.grid_range(month)
    first = month.to_date.beginning_of_month
    last = first.end_of_month
    first.beginning_of_week(:sunday).beginning_of_day..last.end_of_week(:sunday).end_of_day
  end

  private

  def build_weeks
    by_date = @blocks.group_by { |b| b.starts_at.to_date }
    grid_start = @month.beginning_of_week(:sunday)
    grid_end = @month.end_of_month.end_of_week(:sunday)

    days = (grid_start..grid_end).map do |date|
      day_blocks = by_date[date] || []
      Day.new(
        date: date,
        in_month: date.month == @month.month,
        majority: majority_for(day_blocks),
        total_seconds: day_blocks.sum(&:duration)
      )
    end

    days.each_slice(7).to_a
  end

  def majority_for(day_blocks)
    working = day_blocks.reject { |b| b.quadrant == "break" }
    return nil if working.empty?

    by_quadrant = Hash.new(0.0)
    working.each { |b| by_quadrant[b.quadrant] += b.duration }

    # Most time wins; ties broken by Quadrant::WORKING order (q1 wins over q2 etc).
    top_key, _seconds = by_quadrant.min_by { |key, secs| [-secs, Quadrant::WORKING.index(key) || Float::INFINITY] }
    Quadrant.new(top_key)
  end
end
