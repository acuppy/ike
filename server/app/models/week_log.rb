# A single Sunday-through-Saturday calendar week. Given the week's blocks and
# its start_date (must be a Sunday), produces seven Day structs and a label.
# Pure derivation — the controller picks the week, this object computes its
# shape.
class WeekLog
  Day = Struct.new(:date, :label, :total_seconds, :stack, :in_future, keyword_init: true)
  StackPiece = Struct.new(:quadrant, :fraction, keyword_init: true)

  DAY_LABELS = %w[Su Mo Tu We Th Fr Sa].freeze
  DAY_LABELS_LONG = %w[Sun Mon Tue Wed Thu Fri Sat].freeze

  attr_reader :start_date, :blocks

  def initialize(blocks, start_date:)
    @start_date = start_date.to_date
    @blocks = blocks
  end

  def end_date
    start_date + 6.days
  end

  def total_seconds
    blocks.sum(&:duration)
  end

  # "May 24 – 30" / "Apr 26 – May 2" — bridges months when needed. Year is
  # dropped for the compact stream; the date alone is enough context.
  def label
    if start_date.month == end_date.month
      "#{start_date.strftime("%b %-d")} – #{end_date.strftime("%-d")}"
    else
      "#{start_date.strftime("%b %-d")} – #{end_date.strftime("%b %-d")}"
    end
  end

  def days(today: Date.current)
    by_date = blocks.group_by { |b| b.starts_at.in_time_zone.to_date }
    (start_date..end_date).map do |date|
      day_blocks = by_date[date] || []
      total = day_blocks.sum(&:duration)
      Day.new(
        date: date,
        label: DAY_LABELS[date.wday],
        total_seconds: total,
        stack: stack_for(day_blocks, total),
        in_future: date > today
      )
    end
  end

  private

  # Quadrant fractions in reverse canonical order (so q1 stacks on top, as in
  # the macOS chart), skipping empties.
  def stack_for(day_blocks, total)
    return [] if total <= 0

    by_quadrant = Hash.new(0.0)
    day_blocks.each { |b| by_quadrant[b.quadrant] += b.duration }

    Quadrant::ALL.reverse.filter_map do |key|
      seconds = by_quadrant[key]
      next if seconds <= 0

      StackPiece.new(quadrant: Quadrant.new(key), fraction: seconds / total)
    end
  end
end
