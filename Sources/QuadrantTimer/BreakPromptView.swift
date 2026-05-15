import SwiftUI

struct BreakPromptView: View {
    let elapsed: TimeInterval
    let onContinue: () -> Void
    let onEnd: () -> Void

    @State private var secondsRemaining: Int = 10
    @State private var isCountingDown: Bool = true

    private let totalSeconds: Int = 10

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 10, height: 10)
                        Text("Continue break?")
                            .font(.headline)
                    }
                    Text("On break for \(formatElapsed(elapsed)). \(isCountingDown ? "Continues in \(secondsRemaining)s." : "Paused.")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isCountingDown {
                    CountdownRing(seconds: secondsRemaining, total: totalSeconds)
                }
            }

            HStack(spacing: 8) {
                Button("End break") { onEnd() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Continue") { onContinue() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(18)
        .frame(width: 380)
        .onHover { hovering in
            if hovering { isCountingDown = false }
        }
        .task {
            await runCountdown()
        }
    }

    private func runCountdown() async {
        while secondsRemaining > 0 {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            if Task.isCancelled { return }
            if !isCountingDown { return }
            secondsRemaining -= 1
        }
        guard isCountingDown else { return }
        onContinue()
    }

    private func formatElapsed(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        let h = total / 3600
        let m = (total % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m) min"
    }
}
