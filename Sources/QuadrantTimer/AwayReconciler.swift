import Foundation

// Functional core for reconciling time spent away from the desk (system sleep
// or screen lock). Given the facts at the moment of return, it decides what
// should happen — pure input → output, no clocks, no side effects — so the
// gap-filling logic (the part that had the bug) is testable without AppKit.
// AppCoordinator is the imperative shell that captures the inputs and performs
// the resulting action.
struct AwayReconciler {
    // Absences shorter than this (a quick screen lock, a glance away) are
    // ignored — we just resume rather than logging an away block.
    var minimumAwayInterval: TimeInterval = 60

    enum Outcome: Equatable {
        case resume                 // too brief to matter — pick up where we left off
        case stop                   // came back off the clock — nothing to log
        case fill(BlockEntry)       // log this entry to keep the timeline gap-free

        // The entry to log, when the outcome is a fill; nil otherwise.
        var filledEntry: BlockEntry? {
            guard case .fill(let entry) = self else { return nil }
            return entry
        }
    }

    func reconcile(
        awayStart: Date,
        returnedAt: Date,
        blockStart: Date,
        scheduleActive: Bool,
        logging: AwayLogging,
        lastQuadrant: Quadrant?,
        lastNote: String
    ) -> Outcome {
        guard returnedAt.timeIntervalSince(awayStart) >= minimumAwayInterval else { return .resume }
        guard scheduleActive else { return .stop }

        switch logging {
        case .continuation:
            return .fill(BlockEntry(
                start: blockStart, end: returnedAt,
                quadrant: lastQuadrant ?? .q2, note: lastNote, auto: true
            ))
        case .breakTime:
            return .fill(BlockEntry(
                start: blockStart, end: returnedAt,
                quadrant: .breakTime, note: "", auto: true
            ))
        }
    }
}
