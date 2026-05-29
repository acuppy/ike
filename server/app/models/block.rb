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
  # Any change to a block re-broadcasts the day's aggregate sections (trend +
  # timeline + per-quadrant totals), the week chart, and the month grid that
  # contains this block, plus a per-row action for the entries list. DOM ids
  # are scoped to the date/year-month, so a tab viewing a different day or
  # month silently ignores broadcasts that don't concern it.

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

  # The local-zone date this block belongs to. All day-scoped DOM ids derive
  # from it.
  def local_date
    starts_at.in_time_zone.to_date
  end

  def broadcast_block_created
    broadcast_aggregates
    Turbo::StreamsChannel.broadcast_prepend_to(
      user_stream,
      target: "day-entries-#{local_date.iso8601}",
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

  # Re-renders the day aggregate sections (for this block's day), the week
  # chart, and the month grid that contains this block, and pushes them to
  # the stream.
  def broadcast_aggregates
    return unless user # cascading destroy may have removed the user already

    date = local_date
    day_range = date.beginning_of_day.in_time_zone..date.end_of_day.in_time_zone
    day = DayLog.new(user.blocks.between(day_range.begin, day_range.end).chronological.to_a)

    now = Time.zone.now
    week = WeekLog.new(user.blocks.between((now - 6.days).beginning_of_day, now.end_of_day).chronological.to_a)

    Turbo::StreamsChannel.broadcast_replace_to(user_stream, target: "day-top-#{date.iso8601}",    partial: "dashboard/day_top",    locals: { day: day, date: date })
    Turbo::StreamsChannel.broadcast_replace_to(user_stream, target: "day-bottom-#{date.iso8601}", partial: "dashboard/day_bottom", locals: { day: day, date: date })
    Turbo::StreamsChannel.broadcast_replace_to(user_stream, target: "week-chart",                 partial: "weeks/chart",          locals: { week: week })

    month_date = date.beginning_of_month
    month_range = MonthLog.grid_range(month_date)
    month = MonthLog.new(user.blocks.between(month_range.begin, month_range.end).chronological.to_a, month: month_date)
    Turbo::StreamsChannel.broadcast_replace_to(user_stream, target: "month-grid-#{month.year_month}", partial: "months/calendar", locals: { month: month })
  end
end
