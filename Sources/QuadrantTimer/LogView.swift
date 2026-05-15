import SwiftUI

extension Quadrant {
    var color: Color {
        switch self {
        case .q1: .red
        case .q2: .green
        case .q3: .orange
        case .q4: .gray
        case .breakTime: .blue
        }
    }
}

@MainActor
@Observable
final class LogViewModel {
    var entries: [BlockEntry] = []
    var selectedEntry: BlockEntry? = nil

    func reload() {
        entries = BlockLogger.shared.todayEntries()
    }
}

struct LogView: View {
    let viewModel: LogViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            if viewModel.entries.isEmpty {
                emptyState
            } else {
                timeline
                entryList
                summary
            }
        }
        .padding(20)
        .frame(width: 520)
        .onAppear { viewModel.reload() }
    }

    private var header: some View {
        HStack {
            Text("Today's blocks")
                .font(.title3.bold())
            Spacer()
            Text(Date(), format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "square.grid.2x2")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No blocks logged yet today")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 100)
    }

    private var totalDuration: TimeInterval {
        viewModel.entries.reduce(0) { $0 + $1.end.timeIntervalSince($1.start) }
    }

    private var timeline: some View {
        VStack(alignment: .leading, spacing: 4) {
            GeometryReader { geo in
                HStack(spacing: 1) {
                    ForEach(Array(viewModel.entries.enumerated()), id: \.offset) { _, entry in
                        let frac = entry.end.timeIntervalSince(entry.start) / max(totalDuration, 1)
                        Rectangle()
                            .fill(entry.quadrant.color)
                            .frame(width: max(2, geo.size.width * CGFloat(frac)))
                    }
                }
            }
            .frame(height: 36)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            HStack {
                if let first = viewModel.entries.first {
                    Text(first.start, format: .dateTime.hour().minute())
                }
                Spacer()
                if let last = viewModel.entries.last {
                    Text(last.end, format: .dateTime.hour().minute())
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            .monospacedDigit()
        }
    }

    private var entryList: some View {
        VStack(spacing: 0) {
            Divider()
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(viewModel.entries, id: \.start) { entry in
                        EntryRow(entry: entry, isSelected: viewModel.selectedEntry?.start == entry.start)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if viewModel.selectedEntry?.start == entry.start {
                                    viewModel.selectedEntry = nil
                                } else {
                                    viewModel.selectedEntry = entry
                                }
                            }
                        Divider().padding(.leading, 12)
                    }
                }
            }
            .frame(maxHeight: 240)
            Divider()
        }
    }

    private var summary: some View {
        VStack(spacing: 8) {
            ForEach(Quadrant.allCases) { q in
                let qEntries = viewModel.entries.filter { $0.quadrant == q }
                let total = qEntries.reduce(0.0) { $0 + $1.end.timeIntervalSince($1.start) }
                HStack {
                    Circle()
                        .fill(q.color)
                        .frame(width: 10, height: 10)
                    Text(q.label)
                        .font(.subheadline)
                    Spacer()
                    Text(formatDuration(total))
                        .monospacedDigit()
                        .foregroundStyle(qEntries.isEmpty ? .tertiary : .primary)
                    Text("·")
                        .foregroundStyle(.tertiary)
                    Text("\(qEntries.count) block\(qEntries.count == 1 ? "" : "s")")
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline)
            }
            Divider()
            HStack {
                Text("Total")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(formatDuration(totalDuration)) · \(viewModel.entries.count) blocks")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
            }
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        let h = total / 3600
        let m = (total % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }
}

private struct EntryRow: View {
    let entry: BlockEntry
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Text(timeRange)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 96, alignment: .leading)

            Circle()
                .fill(entry.quadrant.color)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.quadrant.label)
                    .font(.subheadline)
                if !entry.note.isEmpty {
                    Text(entry.note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Text(duration)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
    }

    private var timeRange: String {
        let fmt = Date.FormatStyle().hour(.defaultDigits(amPM: .omitted)).minute(.twoDigits)
        return "\(entry.start.formatted(fmt)) – \(entry.end.formatted(fmt))"
    }

    private var duration: String {
        let secs = Int(entry.end.timeIntervalSince(entry.start).rounded())
        let h = secs / 3600
        let m = (secs % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }
}
