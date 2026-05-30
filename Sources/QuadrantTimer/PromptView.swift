import SwiftUI

struct PromptView: View {
    let lastQuadrant: Quadrant?
    let lastNote: String
    let calendarContext: CalendarContext?
    let onSubmit: (Quadrant, String) -> Void
    let onAutoLog: (Quadrant, String) -> Void

    @State private var selected: Quadrant?
    @State private var note: String = ""
    // The most recent value we auto-filled into `note`. When `note` still
    // equals this, the user hasn't typed — so we can keep auto-updating on
    // quadrant change. As soon as the user edits, `note != lastAutoFilled`
    // and we leave it alone.
    @State private var lastAutoFilled: String = ""
    @State private var secondsRemaining: Int = 10
    @State private var isCountingDown: Bool = true
    @FocusState private var noteFocused: Bool

    private let totalSeconds: Int = 10

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            if let context = calendarContext, !context.isEmpty {
                calendarBanner(context)
            }
            grid
            TextField("Note (optional)", text: $note)
                .textFieldStyle(.roundedBorder)
                .focused($noteFocused)
                .onSubmit(submit)
            footer
        }
        .padding(18)
        .frame(width: 460)
        .onAppear {
            selected = lastQuadrant
            let suggested = suggestedNote(for: selected)
            note = suggested
            lastAutoFilled = suggested
            noteFocused = true
        }
        .onChange(of: selected) { _, newSelected in
            // Only swap the suggested note if the user hasn't typed anything
            // yet. If they edited the field, we never overwrite their text.
            guard note == lastAutoFilled else { return }
            let suggested = suggestedNote(for: newSelected)
            note = suggested
            lastAutoFilled = suggested
        }
        .onChange(of: note) { _, _ in pauseCountdown() }
        .background(shortcutButtons)
        .task {
            await runCountdown()
        }
    }

    // The auto-fill rule: if the user is continuing on the same quadrant
    // they last submitted, duplicate that note. Otherwise, fall back to the
    // calendar event description (or empty if there's no overlapping event).
    private func suggestedNote(for quadrant: Quadrant?) -> String {
        if let quadrant, let last = lastQuadrant, quadrant == last {
            return lastNote
        }
        return calendarContext?.joinedTitles ?? ""
    }

    private func calendarBanner(_ context: CalendarContext) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "calendar")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("You were in: ")
                .foregroundStyle(.secondary) +
            Text(context.joinedTitles)
                .foregroundStyle(.primary)
        }
        .font(.caption)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.secondary.opacity(0.08))
        )
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("What are you working on?")
                    .font(.headline)
                Text(isCountingDown
                     ? "Auto-logs in \(secondsRemaining)s"
                     : "Paused — press ↩ to submit")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if isCountingDown {
                CountdownRing(seconds: secondsRemaining, total: totalSeconds)
            }
        }
    }

    private var grid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
            ForEach(Quadrant.working) { q in
                QuadrantTile(quadrant: q, isSelected: selected == q) {
                    selected = q
                    pauseCountdown()
                }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Text("⌘1–4 select")
            Text("·")
            Text("↩ submit")
            Text("·")
            Text("⎋ auto-log now")
            Spacer()
            Button("Submit", action: submit)
                .keyboardShortcut(.defaultAction)
                .disabled(selected == nil)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private var shortcutButtons: some View {
        ZStack {
            ForEach(Quadrant.working) { q in
                Button("") {
                    selected = q
                    pauseCountdown()
                }
                .keyboardShortcut(KeyEquivalent(Character("\(q.shortcutDigit)")), modifiers: .command)
                .frame(width: 0, height: 0)
                .opacity(0)
            }
            Button("") {
                onAutoLog(selected ?? lastQuadrant ?? .q2, note.trimmingCharacters(in: .whitespacesAndNewlines))
            }
            .keyboardShortcut(.cancelAction)
            .frame(width: 0, height: 0)
            .opacity(0)
        }
    }

    private func submit() {
        let q = selected ?? lastQuadrant ?? .q2
        onSubmit(q, note.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func pauseCountdown() {
        isCountingDown = false
    }

    private func runCountdown() async {
        while secondsRemaining > 0 {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            if Task.isCancelled { return }
            if !isCountingDown { return }
            secondsRemaining -= 1
        }
        guard isCountingDown else { return }
        onAutoLog(selected ?? lastQuadrant ?? .q2, note.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}

private struct QuadrantTile: View {
    let quadrant: Quadrant
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Circle()
                    .fill(quadrant.color)
                    .frame(width: 10, height: 10)
                Text("⌘\(quadrant.shortcutDigit)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                Text(quadrant.label)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.22) : Color.gray.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

struct CountdownRing: View {
    let seconds: Int
    let total: Int

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.2), lineWidth: 3)
            Circle()
                .trim(from: 0, to: CGFloat(max(0, seconds)) / CGFloat(total))
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: seconds)
            Text("\(seconds)")
                .font(.system(.caption, design: .monospaced))
                .monospacedDigit()
        }
        .frame(width: 32, height: 32)
    }
}
