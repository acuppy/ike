import Foundation
import Observation

@MainActor
@Observable
final class ScheduleMonitor {
    let settings: ScheduleSettings
    private(set) var isActive: Bool = false
    private(set) var nextActivation: Date? = nil

    var onActivate: (() -> Void)?
    var onDeactivate: (() -> Void)?

    private var timer: Timer?

    init(settings: ScheduleSettings) {
        self.settings = settings
        refresh(fireCallbacks: false)
    }

    func start() {
        guard timer == nil else { return }
        let t = Timer(timeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func refresh(fireCallbacks: Bool = true) {
        let now = Date()
        if let until = settings.workOverrideUntil, until <= now {
            settings.workOverrideUntil = nil
        }
        if let until = settings.endDayUntil, until <= now {
            settings.endDayUntil = nil
        }
        let wasActive = isActive
        isActive = settings.isActive(at: now)
        nextActivation = settings.nextActivation(from: now)
        if fireCallbacks && wasActive != isActive {
            (isActive ? onActivate : onDeactivate)?()
        }
    }

    func enableWorkOverrideUntilEndOfDay() {
        let endOfDay = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: Date()) ?? Date()
        settings.workOverrideUntil = endOfDay
        settings.endDayUntil = nil
        refresh()
    }

    func clearWorkOverride() {
        settings.workOverrideUntil = nil
        refresh()
    }

    func endDayUntilMidnight() {
        let endOfDay = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: Date()) ?? Date()
        settings.endDayUntil = endOfDay
        settings.workOverrideUntil = nil
        refresh()
    }

    func clearEndDay() {
        settings.endDayUntil = nil
        refresh()
    }
}
