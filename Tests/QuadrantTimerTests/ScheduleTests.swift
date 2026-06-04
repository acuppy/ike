import Testing
import Foundation

// Pure schedule math: when is the timer considered "active"? Dates are built
// in the current calendar so the weekday + minute-of-day logic is deterministic.
@MainActor
struct ScheduleTests {
    private func date(weekday: Weekday, hour: Int, minute: Int = 0) -> Date {
        let comps = DateComponents(hour: hour, minute: minute, weekday: weekday.rawValue)
        return Calendar.current.nextDate(
            after: Date(timeIntervalSinceReferenceDate: 0),
            matching: comps,
            matchingPolicy: .nextTime
        )!
    }

    private func workdaySettings() -> ScheduleSettings {
        let settings = ScheduleSettings()
        settings.monday = DaySchedule(enabled: true, startMinutes: 9 * 60, endMinutes: 17 * 60)
        return settings
    }

    @Test("active inside a working day's hours")
    func activeDuringWorkday() {
        #expect(workdaySettings().isActive(at: date(weekday: .monday, hour: 10)))
    }

    @Test("inactive before start and at/after end")
    func inactiveOutsideHours() {
        let settings = workdaySettings()
        #expect(!settings.isActive(at: date(weekday: .monday, hour: 8)))
        #expect(!settings.isActive(at: date(weekday: .monday, hour: 17)))
    }

    @Test("inactive on a disabled day")
    func inactiveOnDisabledDay() {
        let settings = ScheduleSettings()
        settings.sunday = DaySchedule(enabled: false, startMinutes: 9 * 60, endMinutes: 17 * 60)
        #expect(!settings.isActive(at: date(weekday: .sunday, hour: 12)))
    }

    @Test("ending the day suppresses an otherwise-active time")
    func endDaySuppresses() {
        let settings = workdaySettings()
        let noon = date(weekday: .monday, hour: 12)
        settings.endDayUntil = noon.addingTimeInterval(3600)
        #expect(!settings.isActive(at: noon))
    }

    @Test("away logging defaults to continuation")
    func awayLoggingDefault() {
        #expect(ScheduleSettings().awayLogging == .continuation)
    }
}
