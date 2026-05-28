module ApplicationHelper
  # "1h 23m" / "45m" — matches the macOS formatDuration.
  def format_duration(seconds)
    total = seconds.round
    return "0m" if total <= 0

    hours = total / 3600
    minutes = (total % 3600) / 60
    hours.positive? ? "#{hours}h #{minutes}m" : "#{minutes}m"
  end

  # "9:05 AM"
  def format_time(time)
    return "" if time.nil?

    time.strftime("%-l:%M %p")
  end

  # Nav item that highlights when its path is current.
  def nav_link(label, path)
    active = current_page?(path)
    classes = active ? "text-gray-900 font-medium" : "text-gray-500 hover:text-gray-900"
    link_to label, path, class: classes
  end
end
