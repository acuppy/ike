# The last seven days as stacked columns. Port of WeeklyView.swift.
# Each Day knows its total time and the per-quadrant fractions that make up
# its stacked bar, so the view just maps over them.
class WeekLog
  Day = Struct.new(:date, :label, :total_seconds, :stack, keyword_init: true)
  StackPiece = Struct.new(:quadrant, :fraction, keyword_init: true)

  DAY_LABELS = %w[Su Mo Tu We Th Fr Sa].freeze

  attr_reader :blocks

  def initialize(blocks)
    @blocks = blocks
  end

  def empty?
    blocks.empty?
  end

  # Seven Day structs, oldest first, ending today.
  def days(today: Date.current)
    (-6..0).map do |offset|
      date = today + offset
      build_day(date)
    end
  end

  private

  def build_day(date)
    range = date.beginning_of_day...(date + 1).beginning_of_day
    day_blocks = blocks.select { |b| range.cover?(b.starts_at) }
    total = day_blocks.sum(&:duration)

    Day.new(
      date: date,
      label: DAY_LABELS[date.wday],
      total_seconds: total,
      stack: stack_for(day_blocks, total)
    )
  end

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
