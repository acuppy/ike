# A day's worth of blocks plus the derived figures the dashboard renders:
# the total time, per-quadrant breakdown, timeline segments, and trend.
# Pure functional core — give it blocks, ask it questions, no side effects.
class DayLog
  QuadrantTotal = Struct.new(:quadrant, :seconds, :count, keyword_init: true)
  Segment = Struct.new(:quadrant, :fraction, keyword_init: true)

  attr_reader :blocks

  def initialize(blocks)
    @blocks = blocks.sort_by(&:starts_at)
  end

  def empty?
    blocks.empty?
  end

  def total_seconds
    blocks.sum(&:duration)
  end

  def trend
    TrendingSummary.compute(blocks)
  end

  # One QuadrantTotal per quadrant, in canonical order, including zeros.
  def quadrant_totals
    Quadrant::ALL.map do |key|
      matching = blocks.select { |b| b.quadrant == key }
      QuadrantTotal.new(
        quadrant: Quadrant.new(key),
        seconds: matching.sum(&:duration),
        count: matching.length
      )
    end
  end

  # Proportional widths for the colored timeline bar.
  def segments
    total = [total_seconds, 1].max
    blocks.map do |b|
      Segment.new(quadrant: b.quadrant_value, fraction: b.duration / total)
    end
  end

  def first_start
    blocks.first&.starts_at
  end

  def last_end
    blocks.last&.ends_at
  end
end
