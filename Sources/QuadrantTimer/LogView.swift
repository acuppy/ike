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

struct TrendingSummary {
    let caption: String
    let label: String
    let tint: Color

    static let minTotalTime: TimeInterval = 2 * 60 * 60
    static let minEvents: Int = 4
    static let dominanceThreshold: Double = 0.45

    static func compute(from entries: [BlockEntry]) -> TrendingSummary? {
        let working = entries.filter { $0.quadrant != .breakTime }
        let totalTime = working.reduce(0.0) { $0 + $1.end.timeIntervalSince($1.start) }
        guard totalTime > 0 else { return nil }
        guard totalTime >= minTotalTime || working.count >= minEvents else { return nil }

        var byQuadrant: [Quadrant: TimeInterval] = [:]
        for entry in working {
            byQuadrant[entry.quadrant, default: 0] += entry.end.timeIntervalSince(entry.start)
        }
        let sorted = byQuadrant.sorted { $0.value > $1.value }
        guard let top = sorted.first else { return nil }

        if top.value / totalTime >= dominanceThreshold {
            return TrendingSummary(
                caption: "Today is trending toward",
                label: top.key.label,
                tint: top.key.color
            )
        }
        guard sorted.count >= 2 else { return nil }
        let second = sorted[1]
        return TrendingSummary(
            caption: "Today is mixed",
            label: "\(top.key.label) · \(second.key.label)",
            tint: .secondary
        )
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

    func updateEntry(originalStart: Date, quadrant: Quadrant, note: String) {
        guard let idx = entries.firstIndex(where: { $0.start == originalStart }) else { return }
        let original = entries[idx]
        let updated = BlockEntry(
            start: original.start,
            end: original.end,
            quadrant: quadrant,
            note: note,
            auto: original.auto
        )
        entries[idx] = updated
        BlockLogger.shared.update(updated, identifiedBy: originalStart)
        selectedEntry = nil
    }
}

struct LogView: View {
    let viewModel: LogViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !viewModel.entries.isEmpty,
               let trend = TrendingSummary.compute(from: viewModel.entries) {
                trendingBanner(trend)
            }
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

    private func trendingBanner(_ trend: TrendingSummary) -> some View {
        HStack(alignment: .center, spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(trend.tint)
                .frame(width: 4)
            VStack(alignment: .leading, spacing: 2) {
                Text(trend.caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(trend.label)
                    .font(.title3.weight(.semibold))
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(trend.tint.opacity(0.12))
        )
    }

    private var entryList: some View {
        VStack(spacing: 0) {
            Divider()
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(viewModel.entries.reversed(), id: \.start) { entry in
                        let isSelected = viewModel.selectedEntry?.start == entry.start
                        VStack(spacing: 0) {
                            EntryRow(entry: entry, isSelected: isSelected)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    viewModel.selectedEntry = isSelected ? nil : entry
                                }
                            if isSelected {
                                EditPanel(
                                    entry: entry,
                                    onSave: { quadrant, note in
                                        viewModel.updateEntry(originalStart: entry.start, quadrant: quadrant, note: note)
                                    },
                                    onCancel: { viewModel.selectedEntry = nil }
                                )
                            }
                        }
                        Divider().padding(.leading, 12)
                    }
                }
            }
            .frame(height: 240)
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

private struct EditPanel: View {
    let entry: BlockEntry
    let onSave: (Quadrant, String) -> Void
    let onCancel: () -> Void

    @State private var quadrant: Quadrant
    @State private var note: String
    @FocusState private var noteFocused: Bool

    init(entry: BlockEntry, onSave: @escaping (Quadrant, String) -> Void, onCancel: @escaping () -> Void) {
        self.entry = entry
        self.onSave = onSave
        self.onCancel = onCancel
        self._quadrant = State(initialValue: entry.quadrant)
        self._note = State(initialValue: entry.note)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Picker("", selection: $quadrant) {
                    ForEach(Quadrant.allCases) { q in
                        Text(q.label).tag(q)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .fixedSize()

                TextField("Description", text: $note)
                    .textFieldStyle(.roundedBorder)
                    .focused($noteFocused)
                    .onSubmit { onSave(quadrant, note) }
            }
            HStack {
                Text("⏎ save · ⎋ cancel")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Save") { onSave(quadrant, note) }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.accentColor.opacity(0.08))
        .onAppear { noteFocused = true }
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
