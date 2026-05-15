import Foundation
import Observation

@MainActor
@Observable
final class BreakState {
    private(set) var isActive: Bool = false
    private(set) var startedAt: Date?
    private(set) var elapsed: TimeInterval = 0

    var onEnd: ((Date, Date) -> Void)?

    private var timer: Timer?

    func start() {
        guard !isActive else { return }
        let now = Date()
        startedAt = now
        isActive = true
        elapsed = 0

        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func end() {
        guard isActive, let start = startedAt else { return }
        let endDate = Date()
        timer?.invalidate()
        timer = nil
        isActive = false
        startedAt = nil
        elapsed = 0
        onEnd?(start, endDate)
    }

    var formattedElapsed: String {
        let total = Int(elapsed.rounded())
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }

    private func tick() {
        guard let startedAt else { return }
        elapsed = Date().timeIntervalSince(startedAt)

        let cal = Calendar.current
        let breakDay = cal.startOfDay(for: startedAt)
        if let nextDay = cal.date(byAdding: .day, value: 1, to: breakDay), Date() >= nextDay {
            end()
        }
    }
}
