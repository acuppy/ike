import SwiftUI
import EventKit

struct PreferencesView: View {
    @Bindable var settings: ScheduleSettings
    @Bindable var loginItem: LoginItem
    @Bindable var serverSettings: ServerSettings
    @Bindable var blockSyncer: BlockSyncer
    @Bindable var calendarStore: CalendarStore
    let onConnect: () -> Void
    let onDisconnect: () -> Void

    // The window hugs its content but stops growing past this; beyond it the
    // panel scrolls so the bottom stays reachable on short displays (the
    // calendar list can otherwise push Server off-screen).
    @State private var contentHeight: CGFloat?
    private let maxBodyHeight: CGFloat = 580

    var body: some View {
        ScrollView {
            content
                .background(GeometryReader { geo in
                    Color.clear.preference(key: ContentHeightKey.self, value: geo.size.height)
                })
        }
        .frame(width: 460, height: min(contentHeight ?? maxBodyHeight, maxBodyHeight))
        .onPreferenceChange(ContentHeightKey.self) { height in
            // Ignore the transient 0 the GeometryReader reports before the
            // content lays out — clamping to it would collapse the window.
            if height > 0 { contentHeight = height }
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Launch at login — header removed; the toggle + helper text speak
            // for themselves.
            VStack(alignment: .leading, spacing: 8) {
                Toggle("Launch Ike at login", isOn: Binding(
                    get: { loginItem.isEnabled },
                    set: { loginItem.setEnabled($0) }
                ))
                .toggleStyle(.switch)
                .controlSize(.small)
                .tint(.blue)
                Text("Ike will start automatically when you log in to your Mac.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            // Block duration — header removed.
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Block duration")
                    Spacer()
                    Stepper(value: Binding(
                        get: { settings.blockDurationMinutes },
                        set: { settings.blockDurationMinutes = $0; settings.save() }
                    ), in: 1...120) {
                        Text("\(settings.blockDurationMinutes) min")
                            .monospacedDigit()
                            .frame(width: 60, alignment: .trailing)
                    }
                }
                Text("How long each tracked block runs before the prompt fires. Changes apply on the next block.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            // When away — how to account for time while the Mac sleeps or locks.
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("When away (sleep or lock)")
                    Spacer()
                    Picker("", selection: Binding(
                        get: { settings.awayLogging },
                        set: { settings.awayLogging = $0; settings.save() }
                    )) {
                        ForEach(AwayLogging.allCases) { option in
                            Text(option.label).tag(option)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 200)
                }
                Text("If your Mac sleeps or locks mid-block, that time is logged this way so your day stays gap-free.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            // Working Hours — a small section label since multiple day rows
            // sit below. Body weight + semibold to match the visual rhythm
            // of the inline control labels elsewhere on this screen.
            VStack(alignment: .leading, spacing: 8) {
                Text("Working Hours")
                    .font(.body.weight(.semibold))
                Text("Outside these hours, the timer pauses and prompts are suppressed.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 6) {
                ForEach(Weekday.orderedFromMonday) { day in
                    DayRow(day: day, settings: settings)
                }
            }

            Divider()

            CalendarSection(calendarStore: calendarStore)

            Divider()

            // Server — moved to the bottom, header removed.
            ServerSection(
                serverSettings: serverSettings,
                blockSyncer: blockSyncer,
                onConnect: onConnect,
                onDisconnect: onDisconnect
            )
        }
        .padding(20)
        .frame(width: 460)
    }
}

// Reports the laid-out height of the Preferences content so the window can
// clamp itself and scroll past the cap rather than growing off-screen.
private struct ContentHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct ServerSection: View {
    @Bindable var serverSettings: ServerSettings
    @Bindable var blockSyncer: BlockSyncer
    let onConnect: () -> Void
    let onDisconnect: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Server URL")
                Spacer()
                TextField("https://…", text: $serverSettings.serverURL)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 240)
                    .disabled(serverSettings.isConnected)
            }

            if serverSettings.isConnected {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Signed in as \(serverSettings.connectedEmail ?? "")")
                        .font(.caption)
                    Spacer()
                    Button("Disconnect", action: onDisconnect)
                        .controlSize(.small)
                }
                HStack(spacing: 6) {
                    if blockSyncer.isSyncing {
                        ProgressView().controlSize(.small)
                        Text("Syncing…")
                    } else if let error = blockSyncer.lastError {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text(error)
                    } else if let date = serverSettings.lastSyncedAt {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundStyle(.secondary)
                        Text("Last synced \(date.formatted(.relative(presentation: .named)))")
                    } else {
                        Text("Not synced yet")
                    }
                    Spacer()
                    if blockSyncer.syncDidFail {
                        Button("Retry sync") { blockSyncer.sync() }
                            .controlSize(.small)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            } else {
                HStack {
                    Image(systemName: "circle")
                        .foregroundStyle(.secondary)
                    Text("Not connected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Connect to server…", action: onConnect)
                        .controlSize(.small)
                }
                Text("Opens your browser to sign in with a magic link. Your blocks will be pushed to the server and editable from the web.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct DayRow: View {
    let day: Weekday
    @Bindable var settings: ScheduleSettings

    var body: some View {
        let schedule = settings.schedule(for: day)

        HStack(spacing: 12) {
            Toggle(isOn: Binding(
                get: { schedule.enabled },
                set: { settings.setSchedule(.init(enabled: $0, startMinutes: schedule.startMinutes, endMinutes: schedule.endMinutes), for: day) }
            )) {
                Text(day.displayName)
                    .frame(width: 88, alignment: .leading)
            }
            .toggleStyle(.switch)
            .controlSize(.small)
            .tint(.blue)

            MinuteSlotPicker(minutes: Binding(
                get: { schedule.startMinutes },
                set: { settings.setSchedule(.init(enabled: schedule.enabled, startMinutes: $0, endMinutes: schedule.endMinutes), for: day) }
            ))
            .disabled(!schedule.enabled)

            Text("→")
                .foregroundStyle(.secondary)

            MinuteSlotPicker(minutes: Binding(
                get: { schedule.endMinutes },
                set: { settings.setSchedule(.init(enabled: schedule.enabled, startMinutes: schedule.startMinutes, endMinutes: $0), for: day) }
            ))
            .disabled(!schedule.enabled)

            Spacer()
        }
        .opacity(schedule.enabled ? 1.0 : 0.6)
    }
}

// Dropdown of 48 half-hour slots from 12:00 AM through 11:30 PM. The bound
// value is minutes-from-midnight; on display we snap to the nearest slot so
// pre-existing schedules with off-grid minutes (e.g. 8:15) still match a
// menu option and the menu doesn't render with no selection.
private struct MinuteSlotPicker: View {
    @Binding var minutes: Int

    var body: some View {
        Picker("", selection: Binding(
            get: { snap(minutes) },
            set: { minutes = $0 }
        )) {
            ForEach(0..<48, id: \.self) { slot in
                let m = slot * 30
                Text(formatTime(m)).tag(m)
            }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .frame(width: 100)
    }

    private func snap(_ m: Int) -> Int {
        let rounded = ((m + 15) / 30) * 30
        return min(max(rounded, 0), 23 * 60 + 30)
    }

    private func formatTime(_ m: Int) -> String {
        let h24 = m / 60
        let mins = m % 60
        let h12 = h24 == 0 ? 12 : (h24 > 12 ? h24 - 12 : h24)
        let suffix = h24 < 12 ? "AM" : "PM"
        return String(format: "%d:%02d %@", h12, mins, suffix)
    }
}

private struct CalendarSection: View {
    @Bindable var calendarStore: CalendarStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if calendarStore.isAuthorized {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Calendar access granted")
                        .font(.caption)
                } else if calendarStore.authorizationStatus == .denied
                            || calendarStore.authorizationStatus == .restricted {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("Calendar access denied")
                        .font(.caption)
                } else {
                    Image(systemName: "circle")
                        .foregroundStyle(.secondary)
                    Text("Calendar access not granted")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if calendarStore.isAuthorized {
                    Text(headerCountLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if calendarStore.authorizationStatus == .denied
                            || calendarStore.authorizationStatus == .restricted {
                    Button("Open System Settings") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .controlSize(.small)
                } else {
                    Button("Connect calendars") {
                        Task { await calendarStore.requestAccess() }
                    }
                    .controlSize(.small)
                }
            }
            Text("Ike uses your calendars to pre-fill block notes with the event you were in. Add Google calendars in System Settings → Internet Accounts and they show up here. Read-only; titles never leave your machine on their own.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if calendarStore.isAuthorized && !calendarStore.allCalendars.isEmpty {
                CalendarList(calendarStore: calendarStore)
            }
        }
    }

    private var headerCountLabel: String {
        if calendarStore.useAllCalendars {
            let n = calendarStore.calendarCount
            return "\(n) calendar\(n == 1 ? "" : "s")"
        } else {
            return "\(calendarStore.enabledCalendars.count) of \(calendarStore.calendarCount) enabled"
        }
    }
}

// List of available calendars grouped by source (Google account, iCloud,
// etc.) — each row a toggle that adds/removes from the disabled-IDs set.
// Muted calendars are excluded at fetch time so their events never reach
// the prompt.
private struct CalendarList: View {
    @Bindable var calendarStore: CalendarStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Master switch — on, read everything; off, reveal the
            // per-calendar mute list. Disabled selections are preserved
            // either way so flipping back and forth doesn't lose state.
            HStack {
                Text("All calendars")
                Spacer()
                Toggle("", isOn: $calendarStore.useAllCalendars)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .tint(.blue)
            }

            if !calendarStore.useAllCalendars {
                ForEach(grouped(), id: \.0) { source, calendars in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(source)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                        ForEach(calendars, id: \.calendarIdentifier) { cal in
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(Color(cgColor: cal.cgColor))
                                    .frame(width: 8, height: 8)
                                Text(cal.title)
                                    .font(.caption)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Spacer()
                                Toggle("", isOn: Binding(
                                    get: { calendarStore.isEnabled(cal) },
                                    set: { calendarStore.setEnabled($0, for: cal) }
                                ))
                                .labelsHidden()
                                .toggleStyle(.switch)
                                .controlSize(.small)
                                .tint(.blue)
                            }
                        }
                    }
                }
            }
        }
    }

    // Group calendars by source.title (e.g. "iCloud", "Google", or the
    // Google account email when there are multiple). Sources sorted A→Z so
    // the list is stable across launches.
    private func grouped() -> [(String, [EKCalendar])] {
        let dict = Dictionary(grouping: calendarStore.allCalendars) { $0.source.title }
        return dict
            .map { ($0.key, $0.value.sorted { $0.title < $1.title }) }
            .sorted { $0.0 < $1.0 }
    }
}

