import Testing
import Foundation

// The functional core that decides how to account for time spent away
// (sleep/lock). These cover the behavior that produced the original gap bug.
struct AwayReconcilerTests {
    private let reconciler = AwayReconciler()
    private let t0 = Date(timeIntervalSinceReferenceDate: 0)

    @Test("a brief absence just resumes — nothing logged")
    func briefResumes() {
        let outcome = reconciler.reconcile(
            awayStart: t0, returnedAt: t0.addingTimeInterval(30), blockStart: t0,
            scheduleActive: true, logging: .continuation, lastQuadrant: .q1, lastNote: "x"
        )
        #expect(outcome == .resume)
    }

    @Test("returning off the clock stops without logging")
    func offClockStops() {
        let outcome = reconciler.reconcile(
            awayStart: t0, returnedAt: t0.addingTimeInterval(600), blockStart: t0,
            scheduleActive: false, logging: .continuation, lastQuadrant: .q1, lastNote: "x"
        )
        #expect(outcome == .stop)
    }

    @Test("continuation fills the gap with the last activity")
    func continuationFill() {
        let ret = t0.addingTimeInterval(3000)
        let outcome = reconciler.reconcile(
            awayStart: t0.addingTimeInterval(60), returnedAt: ret, blockStart: t0,
            scheduleActive: true, logging: .continuation, lastQuadrant: .q3, lastNote: "deploys"
        )
        #expect(outcome == .fill(BlockEntry(start: t0, end: ret, quadrant: .q3, note: "deploys", auto: true)))
    }

    @Test("continuation falls back to q2 when nothing has been logged yet")
    func continuationFallback() throws {
        let outcome = reconciler.reconcile(
            awayStart: t0, returnedAt: t0.addingTimeInterval(3000), blockStart: t0,
            scheduleActive: true, logging: .continuation, lastQuadrant: nil, lastNote: ""
        )
        #expect(try #require(outcome.filledEntry).quadrant == .q2)
    }

    @Test("break logs the away span as a break")
    func breakFill() throws {
        let outcome = reconciler.reconcile(
            awayStart: t0, returnedAt: t0.addingTimeInterval(3000), blockStart: t0,
            scheduleActive: true, logging: .breakTime, lastQuadrant: .q1, lastNote: "x"
        )
        let entry = try #require(outcome.filledEntry)
        #expect(entry.quadrant == .breakTime)
        #expect(entry.note == "")
        #expect(entry.auto)
    }

    @Test("the fill spans the interrupted block through return — no gap, no overlap")
    func contiguous() throws {
        let ret = t0.addingTimeInterval(4000)
        let outcome = reconciler.reconcile(
            awayStart: t0.addingTimeInterval(100), returnedAt: ret, blockStart: t0,
            scheduleActive: true, logging: .continuation, lastQuadrant: .q1, lastNote: ""
        )
        let entry = try #require(outcome.filledEntry)
        #expect(entry.start == t0)
        #expect(entry.end == ret)
    }

    @Test("exactly the threshold counts as away")
    func thresholdInclusive() {
        let outcome = reconciler.reconcile(
            awayStart: t0, returnedAt: t0.addingTimeInterval(60), blockStart: t0,
            scheduleActive: true, logging: .breakTime, lastQuadrant: nil, lastNote: ""
        )
        #expect(outcome != .resume)
    }
}
