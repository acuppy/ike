import SwiftUI

struct PreferencesView: View {
    @Bindable var settings: ScheduleSettings
    @Bindable var loginItem: LoginItem
    @Bindable var serverSettings: ServerSettings
    @Bindable var blockSyncer: BlockSyncer
    let onConnect: () -> Void
    let onDisconnect: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Startup")
                    .font(.title3.bold())
                Toggle("Launch Ike at login", isOn: Binding(
                    get: { loginItem.isEnabled },
                    set: { loginItem.setEnabled($0) }
                ))
                .toggleStyle(.switch)
                .controlSize(.small)
                Text("Ike will start automatically when you log in to your Mac.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Timer")
                    .font(.title3.bold())
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

            ServerSection(
                serverSettings: serverSettings,
                blockSyncer: blockSyncer,
                onConnect: onConnect,
                onDisconnect: onDisconnect
            )

            Divider()

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
            Text("Server")
                .font(.title3.bold())

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

            DatePicker("", selection: Binding(
                get: { dateFromMinutes(schedule.startMinutes) },
                set: { settings.setSchedule(.init(enabled: schedule.enabled, startMinutes: minutesFromDate($0), endMinutes: schedule.endMinutes), for: day) }
            ), displayedComponents: .hourAndMinute)
                .labelsHidden()
                .disabled(!schedule.enabled)

            Text("→")
                .foregroundStyle(.secondary)

            DatePicker("", selection: Binding(
                get: { dateFromMinutes(schedule.endMinutes) },
                set: { settings.setSchedule(.init(enabled: schedule.enabled, startMinutes: schedule.startMinutes, endMinutes: minutesFromDate($0)), for: day) }
            ), displayedComponents: .hourAndMinute)
                .labelsHidden()
                .disabled(!schedule.enabled)

            Spacer()
        }
        .opacity(schedule.enabled ? 1.0 : 0.6)
    }

    private func dateFromMinutes(_ minutes: Int) -> Date {
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        return cal.date(byAdding: .minute, value: minutes, to: start) ?? start
    }

    private func minutesFromDate(_ date: Date) -> Int {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
    }
}
