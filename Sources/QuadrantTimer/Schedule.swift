import Foundation
import Observation

enum Weekday: Int, CaseIterable, Identifiable {
    case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday
    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .sunday: "Sunday"
        case .monday: "Monday"
        case .tuesday: "Tuesday"
        case .wednesday: "Wednesday"
        case .thursday: "Thursday"
        case .friday: "Friday"
        case .saturday: "Saturday"
        }
    }

    static var orderedFromMonday: [Weekday] {
        [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday]
    }
}

// How to account for time that passes while the Mac is asleep or locked
// mid-block. Continuation treats it as more of whatever you were last doing;
// break treats it as time off.
enum AwayLogging: String, Codable, CaseIterable, Identifiable {
    case continuation
    case breakTime

    var id: String { rawValue }

    var label: String {
        switch self {
        case .continuation: "Continue last activity"
        case .breakTime: "Log as break"
        }
    }
}

struct DaySchedule: Codable, Equatable {
    var enabled: Bool
    var startMinutes: Int
    var endMinutes: Int

    static let workday = DaySchedule(enabled: true, startMinutes: 9 * 60, endMinutes: 17 * 60)
    static let weekend = DaySchedule(enabled: false, startMinutes: 9 * 60, endMinutes: 17 * 60)
}

@MainActor
@Observable
final class ScheduleSettings {
    var monday    = DaySchedule.workday
    var tuesday   = DaySchedule.workday
    var wednesday = DaySchedule.workday
    var thursday  = DaySchedule.workday
    var friday    = DaySchedule.workday
    var saturday  = DaySchedule.weekend
    var sunday    = DaySchedule.weekend

    var workOverrideUntil: Date?
    var endDayUntil: Date?

    var blockDurationMinutes: Int = 15
    var awayLogging: AwayLogging = .continuation

    private let storageKey = "QuadrantTimer.schedule.v1"

    init() {
        load()
    }

    func save() {
        let snapshot = Snapshot(
            monday: monday, tuesday: tuesday, wednesday: wednesday, thursday: thursday,
            friday: friday, saturday: saturday, sunday: sunday,
            blockDurationMinutes: blockDurationMinutes,
            awayLogging: awayLogging
        )
        if let data = try? JSONEncoder().encode(snapshot) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let snap = try? JSONDecoder().decode(Snapshot.self, from: data) else { return }
        monday = snap.monday
        tuesday = snap.tuesday
        wednesday = snap.wednesday
        thursday = snap.thursday
        friday = snap.friday
        saturday = snap.saturday
        sunday = snap.sunday
        blockDurationMinutes = snap.blockDurationMinutes ?? 15
        awayLogging = snap.awayLogging ?? .continuation
    }

    func schedule(for weekday: Weekday) -> DaySchedule {
        switch weekday {
        case .sunday: sunday
        case .monday: monday
        case .tuesday: tuesday
        case .wednesday: wednesday
        case .thursday: thursday
        case .friday: friday
        case .saturday: saturday
        }
    }

    func setSchedule(_ value: DaySchedule, for weekday: Weekday) {
        switch weekday {
        case .sunday: sunday = value
        case .monday: monday = value
        case .tuesday: tuesday = value
        case .wednesday: wednesday = value
        case .thursday: thursday = value
        case .friday: friday = value
        case .saturday: saturday = value
        }
        save()
    }

    func isActive(at date: Date) -> Bool {
        if let until = endDayUntil, date < until { return false }
        if let until = workOverrideUntil, date < until { return true }
        let cal = Calendar.current
        guard let weekday = Weekday(rawValue: cal.component(.weekday, from: date)) else { return false }
        let day = schedule(for: weekday)
        guard day.enabled else { return false }
        let comps = cal.dateComponents([.hour, .minute], from: date)
        let m = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
        return m >= day.startMinutes && m < day.endMinutes
    }

    func nextActivation(from date: Date) -> Date? {
        let cal = Calendar.current
        for offset in 0..<8 {
            guard let probe = cal.date(byAdding: .day, value: offset, to: date) else { continue }
            guard let weekday = Weekday(rawValue: cal.component(.weekday, from: probe)) else { continue }
            let day = schedule(for: weekday)
            guard day.enabled else { continue }
            let probeDayStart = cal.startOfDay(for: probe)
            guard let startDate = cal.date(byAdding: .minute, value: day.startMinutes, to: probeDayStart) else { continue }
            if startDate > date { return startDate }
        }
        return nil
    }

    private struct Snapshot: Codable {
        var monday: DaySchedule
        var tuesday: DaySchedule
        var wednesday: DaySchedule
        var thursday: DaySchedule
        var friday: DaySchedule
        var saturday: DaySchedule
        var sunday: DaySchedule
        var blockDurationMinutes: Int?
        var awayLogging: AwayLogging?
    }
}
