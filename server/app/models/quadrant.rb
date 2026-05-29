# Value object holding everything we know about an Eisenhower quadrant:
# its key, human label, and display color. Mirrors Quadrant.swift in the
# macOS app so the web and the menu bar widget stay in sync.
class Quadrant
  ALL = %w[q1 q2 q3 q4 break].freeze
  WORKING = %w[q1 q2 q3 q4].freeze

  LABELS = {
    "q1" => "Urgent & Important",
    "q2" => "Important, Not Urgent",
    "q3" => "Urgent, Not Important",
    "q4" => "Neither Urgent nor Important",
    "break" => "Break"
  }.freeze

  # Outcome-focused palette (Tailwind Refined hues): Q2 (the target) emerald,
  # Q4 (regret) rose, Q3 (interruption warning) amber, Q1 (firefighting —
  # neutralized) slate. Mirrors the SwiftUI palette in LogView.swift.
  COLORS = {
    "q1" => "#94a3b8", # slate-400
    "q2" => "#10b981", # emerald-500
    "q3" => "#f59e0b", # amber-500
    "q4" => "#f43f5e", # rose-500
    "break" => "#0ea5e9" # sky-500
  }.freeze

  attr_reader :key

  def self.all
    ALL.map { |key| new(key) }
  end

  def self.working
    WORKING.map { |key| new(key) }
  end

  def initialize(key)
    @key = key.to_s
  end

  def label
    LABELS.fetch(key, key)
  end

  def color
    COLORS.fetch(key, "#9ca3af")
  end

  def working?
    WORKING.include?(key)
  end

  def ==(other)
    other.is_a?(Quadrant) && other.key == key
  end
  alias eql? ==

  def hash
    key.hash
  end

  def to_s
    key
  end
end
