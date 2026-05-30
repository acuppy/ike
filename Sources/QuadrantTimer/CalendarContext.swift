import Foundation
import EventKit

// What the prompt knows about calendar events overlapping a block. Pure value
// object — given a list of EKEvents, computes the display text and the
// suggested note pre-fill. Filtering / sorting decisions live here, not in
// the view.
struct CalendarContext {
    let titles: [String]

    init(events: [EKEvent]) {
        // Sort by duration desc — the most substantial overlap leads the join,
        // so a 5-min standup doesn't bury a 25-min focus block.
        let filtered = events
            .filter { !$0.isAllDay }
            .filter { $0.status != .canceled }
            .filter { !($0.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .filter { $0.responseStatusForCurrentUser() != .declined }
            .sorted { $0.duration > $1.duration }

        self.titles = filtered.compactMap { $0.title?.trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    var isEmpty: Bool { titles.isEmpty }

    // "Standup; 1:1 with Sarah; Deep work" — preserves all overlapping events
    // so nothing is hidden. Editable in the prompt before save.
    var joinedTitles: String {
        titles.joined(separator: "; ")
    }
}

private extension EKEvent {
    var duration: TimeInterval { endDate.timeIntervalSince(startDate) }

    // The current user's RSVP for this event, or .unknown if they're not an
    // attendee (their own calendar's events typically have no attendees).
    func responseStatusForCurrentUser() -> EKParticipantStatus {
        attendees?.first(where: { $0.isCurrentUser })?.participantStatus ?? .unknown
    }
}
