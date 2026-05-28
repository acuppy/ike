class Block < ApplicationRecord
  belongs_to :user

  validates :starts_at, :ends_at, presence: true
  validates :quadrant, inclusion: { in: Quadrant::ALL }
  validate :ends_after_starts

  scope :chronological, -> { order(starts_at: :asc) }
  scope :recent_first, -> { order(starts_at: :desc) }
  scope :working, -> { where(quadrant: Quadrant::WORKING) }

  scope :between, ->(from, to) { where(starts_at: from...to) }

  # --- Live updates via Turbo Streams ---------------------------------------
  # Any change to a block re-broadcasts the two aggregate sections (today
  # totals/trend/timeline and the week chart) plus a per-row action for the
  # entries list. Subscribers see updates without reloading.

  after_create_commit  :broadcast_block_created
  after_update_commit  :broadcast_block_updated
  after_destroy_commit :broadcast_block_destroyed

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

  # --- Broadcast helpers ----------------------------------------------------

  def user_stream
    "user_#{user_id}_blocks"
  end

  def starts_today?(now: Time.zone.now)
    starts_at.between?(now.beginning_of_day, now.end_of_day)
  end

  def broadcast_block_created
    broadcast_aggregates
    return unless starts_today?

    Turbo::StreamsChannel.broadcast_prepend_to(
      user_stream,
      target: "today-entries",
      partial: "blocks/block",
      locals: { block: self }
    )
  end

  def broadcast_block_updated
    broadcast_aggregates
    Turbo::StreamsChannel.broadcast_replace_to(
      user_stream,
      target: ActionView::RecordIdentifier.dom_id(self),
      partial: "blocks/block",
      locals: { block: self }
    )
  end

  def broadcast_block_destroyed
    broadcast_aggregates
    Turbo::StreamsChannel.broadcast_remove_to(
      user_stream,
      target: ActionView::RecordIdentifier.dom_id(self)
    )
  end

  # Re-renders the today aggregate sections and the week chart from this
  # user's current state and pushes them to the stream.
  def broadcast_aggregates
    return unless user # cascading destroy may have removed the user already

    now = Time.zone.now
    day = DayLog.new(user.blocks.between(now.beginning_of_day, now.end_of_day).chronological.to_a)
    week = WeekLog.new(user.blocks.between((now - 6.days).beginning_of_day, now.end_of_day).chronological.to_a)

    Turbo::StreamsChannel.broadcast_replace_to(user_stream, target: "today-top",    partial: "dashboard/today_top",    locals: { day: day })
    Turbo::StreamsChannel.broadcast_replace_to(user_stream, target: "today-bottom", partial: "dashboard/today_bottom", locals: { day: day })
    Turbo::StreamsChannel.broadcast_replace_to(user_stream, target: "week-chart",   partial: "weeks/chart",            locals: { week: week })
  end
end
