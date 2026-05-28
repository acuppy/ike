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

  # Tailwind-friendly hex colors matching the SwiftUI palette.
  COLORS = {
    "q1" => "#ef4444", # red
    "q2" => "#22c55e", # green
    "q3" => "#f97316", # orange
    "q4" => "#9ca3af", # gray
    "break" => "#3b82f6" # blue
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
