# Idempotent seed: a development user with a week of realistic quadrant blocks.
user = User.find_or_create_by!(provider: "developer", uid: "you@example.com") do |u|
  u.email = "you@example.com"
  u.name = "Dev User"
end

user.blocks.destroy_all

# A plausible day: mostly Q2 deep work, some Q1 fires, a couple Q3/Q4, breaks.
day_plan = [
  ["09:00", 50, "q2", "Architecture spike"],
  ["09:50", 10, "break", ""],
  ["10:00", 50, "q2", "Deep work — feature build"],
  ["10:50", 50, "q1", "Prod incident triage"],
  ["11:40", 20, "q3", "Standup + interruptions"],
  ["13:00", 50, "q2", "Writing design doc"],
  ["13:50", 50, "q2", "Pairing on PR review"],
  ["14:40", 25, "q4", "Inbox / slack churn"],
  ["15:10", 50, "q1", "Customer escalation"],
  ["16:00", 50, "q2", "Refactor — extract service object"],
]

7.downto(1) do |days_ago|
  date = Date.current - (days_ago - 1)
  # Skip weekends for a realistic chart.
  next if date.saturday? || date.sunday?

  day_plan.each do |time, minutes, quadrant, note|
    hour, min = time.split(":").map(&:to_i)
    starts_at = Time.zone.local(date.year, date.month, date.day, hour, min)
    user.blocks.create!(
      starts_at: starts_at,
      ends_at: starts_at + minutes.minutes,
      quadrant: quadrant,
      note: note,
      auto: false
    )
  end
end

puts "Seeded #{user.blocks.count} blocks for #{user.email}"
puts "API token: #{user.api_token}"
