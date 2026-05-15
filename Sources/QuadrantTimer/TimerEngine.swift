import Foundation
import Observation

@Observable
@MainActor
final class TimerEngine {
    var blockDurationProvider: () -> TimeInterval = { 15 * 60 }

    private(set) var remaining: TimeInterval = 15 * 60
    private(set) var blockStartedAt: Date = Date()
    private(set) var isPaused: Bool = false

    var onBlockComplete: ((Date, Date) -> Void)?

    private var timer: Timer?

    var blockDuration: TimeInterval { blockDurationProvider() }

    func start() {
        guard timer == nil else { return }
        blockStartedAt = Date()
        remaining = blockDuration
        scheduleTimer()
    }

    func pause() {
        isPaused = true
    }

    func resume() {
        isPaused = false
    }

    func resetBlock() {
        blockStartedAt = Date()
        remaining = blockDuration
        isPaused = false
        if timer == nil { scheduleTimer() }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        isPaused = true
    }

    var formattedRemaining: String {
        let total = max(0, Int(remaining.rounded()))
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }

    private func scheduleTimer() {
        let t = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func tick() {
        guard !isPaused else { return }
        remaining -= 1
        if remaining <= 0 {
            isPaused = true
            let end = Date()
            onBlockComplete?(blockStartedAt, end)
        }
    }
}
