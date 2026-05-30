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

    var authorizationStatus: EKAuthorizationStatus

    init() {
        self.authorizationStatus = EKEventStore.authorizationStatus(for: .event)
    }

    var isAuthorized: Bool {
        // macOS 14+ adds .fullAccess and .writeOnly; we only need read.
        if #available(macOS 14.0, *) {
            return authorizationStatus == .fullAccess || authorizationStatus == .authorized
        }
        return authorizationStatus == .authorized
    }

    var calendarCount: Int {
        guard isAuthorized else { return 0 }
        return store.calendars(for: .event).count
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

    // Returns events overlapping [start, end). All-day events, declined
    // events, and empty-titled events are filtered out by CalendarContext.
    func eventsOverlapping(start: Date, end: Date) -> [EKEvent] {
        guard isAuthorized else { return [] }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        return store.events(matching: predicate)
    }

    // Build a CalendarContext for a block's time range — the shape PromptView
    // and PromptController want.
    func context(for start: Date, end: Date) -> CalendarContext {
        CalendarContext(events: eventsOverlapping(start: start, end: end))
    }
}
