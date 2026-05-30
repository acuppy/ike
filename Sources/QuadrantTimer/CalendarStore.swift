import Foundation
import EventKit
import Observation

// Thin wrapper around EKEventStore. Owns the authorization state, exposes a
// single fetch for events overlapping a time range, and refreshes the
// observable authorization status so SwiftUI views can react to changes.
//
// EventKit reads everything Calendar.app sees — Apple Calendar plus every
// Google org you've added to System Settings → Internet Accounts. Multi-org
// is handled by the OS, not by us.
@MainActor
@Observable
final class CalendarStore {
    static let shared = CalendarStore()

    private let store = EKEventStore()
    private let defaults = UserDefaults.standard
    private let disabledKey = "DisabledCalendarIds"

    var authorizationStatus: EKAuthorizationStatus
    // Calendars the user has muted (only consulted when useAllCalendars is
    // off). Blacklist semantics: any calendar not in this set is read.
    private(set) var disabledCalendarIds: Set<String>
    // When true (default), every available calendar is read and the
    // per-calendar mute list is ignored. Turning this off reveals the
    // mute list in Preferences.
    var useAllCalendars: Bool {
        didSet { defaults.set(useAllCalendars, forKey: "UseAllCalendars") }
    }

    init() {
        self.authorizationStatus = EKEventStore.authorizationStatus(for: .event)
        self.disabledCalendarIds = Set(defaults.stringArray(forKey: "DisabledCalendarIds") ?? [])
        self.useAllCalendars = defaults.object(forKey: "UseAllCalendars") as? Bool ?? true
    }

    var isAuthorized: Bool {
        // macOS 14+ adds .fullAccess and .writeOnly; we only need read.
        if #available(macOS 14.0, *) {
            return authorizationStatus == .fullAccess || authorizationStatus == .authorized
        }
        return authorizationStatus == .authorized
    }

    var calendarCount: Int {
        allCalendars.count
    }

    var allCalendars: [EKCalendar] {
        guard isAuthorized else { return [] }
        return store.calendars(for: .event)
    }

    var enabledCalendars: [EKCalendar] {
        if useAllCalendars {
            return allCalendars
        }
        return allCalendars.filter { isEnabled($0) }
    }

    func isEnabled(_ calendar: EKCalendar) -> Bool {
        !disabledCalendarIds.contains(calendar.calendarIdentifier)
    }

    func setEnabled(_ enabled: Bool, for calendar: EKCalendar) {
        let id = calendar.calendarIdentifier
        if enabled {
            disabledCalendarIds.remove(id)
        } else {
            disabledCalendarIds.insert(id)
        }
        defaults.set(Array(disabledCalendarIds), forKey: disabledKey)
    }

    // Requests full-access permission for events. Safe to call repeatedly —
    // EventKit returns the cached decision after the first prompt.
    func requestAccess() async {
        do {
            if #available(macOS 14.0, *) {
                _ = try await store.requestFullAccessToEvents()
            } else {
                _ = try await store.requestAccess(to: .event)
            }
        } catch {
            NSLog("CalendarStore.requestAccess failed: \(error)")
        }
        self.authorizationStatus = EKEventStore.authorizationStatus(for: .event)
    }

    // Returns events overlapping [start, end), restricted to calendars the
    // user hasn't muted. All-day events, declined events, and empty-titled
    // events are filtered out by CalendarContext.
    func eventsOverlapping(start: Date, end: Date) -> [EKEvent] {
        guard isAuthorized else { return [] }
        let calendars = enabledCalendars
        guard !calendars.isEmpty else { return [] }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: calendars)
        return store.events(matching: predicate)
    }

    // Build a CalendarContext for a block's time range — the shape PromptView
    // and PromptController want.
    func context(for start: Date, end: Date) -> CalendarContext {
        CalendarContext(events: eventsOverlapping(start: start, end: end))
    }
}
