import SwiftUI

struct PreferencesView: View {
    @Bindable var settings: ScheduleSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
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
