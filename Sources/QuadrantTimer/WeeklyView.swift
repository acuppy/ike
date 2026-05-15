import SwiftUI

@MainActor
@Observable
final class WeeklyViewModel {
    var entries: [BlockEntry] = []

    func reload() {
        entries = BlockLogger.shared.weekEntries()
    }
}

struct WeeklyView: View {
    let viewModel: WeeklyViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            if viewModel.entries.isEmpty {
                emptyState
            } else {
                chart
            }
        }
        .padding(20)
        .frame(width: 520)
        .onAppear { viewModel.reload() }
    }

    private var header: some View {
        Text("Weekly trends")
            .font(.title3.bold())
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "square.grid.2x2")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No blocks logged this week")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }

    private var chart: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(0..<7, id: \.self) { dayOffset in
                    dayColumn(dayOffset: dayOffset)
                }
            }
            legend
        }
    }

    private func dayColumn(dayOffset: Int) -> some View {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        guard let date = cal.date(byAdding: .day, value: -6 + dayOffset, to: today),
              let dayEnd = cal.date(byAdding: .day, value: 1, to: date) else {
            return AnyView(EmptyView())
        }

        let dayEntries = viewModel.entries.filter { $0.start >= date && $0.start < dayEnd }
        let totalSeconds = dayEntries.reduce(0) { $0 + $1.end.timeIntervalSince($1.start) }

        return AnyView(
            VStack(spacing: 4) {
                Text(formatDuration(totalSeconds))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(totalSeconds > 0 ? Color.secondary : Color.clear)
                    .frame(height: 14)

                GeometryReader { geo in
                    VStack(spacing: 0) {
                        if totalSeconds > 0 {
                            let quadrantTotals = quadrantTotals(for: dayEntries)
                            ForEach(Quadrant.allCases.reversed()) { q in
                                let frac = quadrantTotals[q, default: 0] / totalSeconds
                                if frac > 0 {
                                    Rectangle()
                                        .fill(q.color)
                                        .frame(height: geo.size.height * CGFloat(frac))
                                }
                            }
                        } else {
                            Rectangle()
                                .fill(Color.primary.opacity(0.06))
                                .frame(maxHeight: .infinity)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                }
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 4))

                Text(shortDayLabel(date))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(height: 14)
            }
            .frame(maxWidth: .infinity)
        )
    }

    private func quadrantTotals(for entries: [BlockEntry]) -> [Quadrant: TimeInterval] {
        var totals: [Quadrant: TimeInterval] = [:]
        for entry in entries {
            totals[entry.quadrant, default: 0] += entry.end.timeIntervalSince(entry.start)
        }
        return totals
    }

    private func shortDayLabel(_ date: Date) -> String {
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: date)
        let symbols = ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
        return symbols[weekday - 1]
    }

    private var legend: some View {
        HStack(spacing: 12) {
            ForEach(Quadrant.allCases) { q in
                HStack(spacing: 4) {
                    Circle()
                        .fill(q.color)
                        .frame(width: 8, height: 8)
                    Text(q.label)
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        guard seconds > 0 else { return "" }
        let total = Int(seconds.rounded())
        let h = total / 3600
        let m = (total % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }
}
