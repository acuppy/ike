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

    var body: some View {
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

            // Working Hours — keeps its header since each day row needs context.
            VStack(alignment: .leading, spacing: 8) {
                Text("Working Hours")
                    .font(.title3.bold())
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
                    Text("Connected as \(serverSettings.connectedEmail ?? "")")
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
                    Button("Connect with Google…", action: onConnect)
                        .controlSize(.small)
                }
                Text("Opens your browser to sign in. Your blocks will be pushed to the server and editable from the web.")
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
                    Text("\(calendarStore.calendarCount) calendar\(calendarStore.calendarCount == 1 ? "" : "s")")
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
        }
    }
}

