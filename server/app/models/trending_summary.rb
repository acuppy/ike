# Pure derivation of the "Today is trending toward ..." banner from a list of
# blocks. Port of TrendingSummary.compute in LogView.swift.
class TrendingSummary
  MIN_TOTAL_TIME = 2 * 60 * 60 # seconds
  MIN_EVENTS = 4
  DOMINANCE_THRESHOLD = 0.45

  attr_reader :caption, :label, :tint

  def initialize(caption:, label:, tint:)
    @caption = caption
    @label = label
    @tint = tint
  end

  # Returns a TrendingSummary or nil when there isn't enough signal yet.
  def self.compute(blocks)
    working = blocks.reject { |b| b.quadrant == "break" }
    total = working.sum(&:duration)
    return nil if total <= 0
    return nil unless total >= MIN_TOTAL_TIME || working.length >= MIN_EVENTS

    by_quadrant = Hash.new(0.0)
    working.each { |b| by_quadrant[b.quadrant] += b.duration }
    sorted = by_quadrant.sort_by { |_key, seconds| -seconds }

    top_key, top_seconds = sorted.first
    if top_seconds / total >= DOMINANCE_THRESHOLD
      top = Quadrant.new(top_key)
      return new(caption: "Today is trending toward", label: top.label, tint: top.color)
    end

    return nil if sorted.length < 2

    second = Quadrant.new(sorted[1].first)
    top = Quadrant.new(top_key)
    new(caption: "Today is mixed", label: "#{top.label} · #{second.label}", tint: nil)
  end
end
