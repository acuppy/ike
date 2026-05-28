class Block < ApplicationRecord
  belongs_to :user

  validates :starts_at, :ends_at, presence: true
  validates :quadrant, inclusion: { in: Quadrant::ALL }
  validate :ends_after_starts

  scope :chronological, -> { order(starts_at: :asc) }
  scope :recent_first, -> { order(starts_at: :desc) }
  scope :working, -> { where(quadrant: Quadrant::WORKING) }

  scope :between, ->(from, to) { where(starts_at: from...to) }

  def quadrant_value
    Quadrant.new(quadrant)
  end

  def duration
    return 0 if starts_at.nil? || ends_at.nil?

    ends_at - starts_at
  end

  private

  def ends_after_starts
    return if starts_at.nil? || ends_at.nil?
    return if ends_at >= starts_at

    errors.add(:ends_at, "must be on or after the start time")
  end
end
