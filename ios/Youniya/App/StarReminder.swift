import SwiftUI
import UserNotifications

/// 87 별 만들기 알림: a quiet local notification at the chosen time, only on
/// days without a new star. Local notifications can't check a condition when
/// they fire, so the next two weeks are scheduled one by one and today's is
/// left out once a star is written. Rescheduled when the setting, the time or
/// the stars change, and when the app comes back (to extend the two weeks).
enum StarReminder {
    private static let prefix = "star-reminder-"
    private static let days = 14

    static let title = "오늘 밤하늘"
    static let body = "오늘 마음에 남은 장면이 있다면, 별로 띄워 볼까요?"

    /// "오후 9:30"
    static func timeText(_ minutes: Int) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "a h:mm"
        return f.string(from: date(minutes, on: .now))
    }

    static func date(_ minutes: Int, on day: Date) -> Date {
        Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: day) ?? day
    }

    @MainActor static func reschedule(_ model: AppModel) {
        let on = model.settings.starReminder
        let minutes = model.settings.reminderMinutes
        // Floated or kept: any star written today counts.
        let wroteToday = model.stars.contains { $0.createdAt.map(Calendar.current.isDateInToday) ?? false }
        Task {
            let center = UNUserNotificationCenter.current()
            let pending = await center.pendingNotificationRequests()
                .map(\.identifier).filter { $0.hasPrefix(prefix) }
            center.removePendingNotificationRequests(withIdentifiers: pending)
            guard on else { return }
            let status = await center.notificationSettings().authorizationStatus
            guard status == .authorized || status == .provisional else { return }

            let cal = Calendar.current
            let today = cal.startOfDay(for: .now)
            for offset in 0..<days {
                guard let day = cal.date(byAdding: .day, value: offset, to: today) else { continue }
                if offset == 0 && wroteToday { continue }
                let fire = date(minutes, on: day)
                guard fire > .now else { continue }
                let content = UNMutableNotificationContent()
                content.title = title
                content.body = body
                content.sound = .default
                let parts = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
                let request = UNNotificationRequest(
                    identifier: prefix + String(cal.ordinality(of: .day, in: .era, for: day) ?? offset),
                    content: content,
                    trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false))
                try? await center.add(request)
            }
        }
    }
}

// MARK: - 87-2 알림 시각 고르기

/// 87-2: "언제 알려 드릴까요?" with an hour/minute wheel (5-minute steps).
struct ReminderTimeSheet: View {
    var minutes: Int
    var onSave: (Int) -> Void
    var onCancel: () -> Void

    @State private var time = Date.now

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            Capsule().fill(Color.borderDefault).frame(width: 40, height: 4)
                .frame(maxWidth: .infinity).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Space.sm) {
                Text("언제 알려 드릴까요?").textStyle(.h3).foregroundStyle(Color.textPrimary)
                Text("별을 띄우지 않은 날에만, 이 시각에 한 번 조용히 알려 드려요.")
                    .textStyle(.bodyM).foregroundStyle(Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            TimeWheel(date: $time)
                .frame(height: 180)
                .frame(maxWidth: .infinity)

            VStack(spacing: Space.md) {
                Button("저장") {
                    let c = Calendar.current.dateComponents([.hour, .minute], from: time)
                    onSave((c.hour ?? 21) * 60 + (c.minute ?? 30))
                }
                .buttonStyle(.primary)
                Button("취소", action: onCancel).buttonStyle(.ghost)
            }
        }
        .padding(.horizontal, Space.xl)
        .padding(.top, Space.md)
        .padding(.bottom, Space.xxl)
        .onAppear { time = StarReminder.date(minutes, on: .now) }
    }
}

/// UIKit's wheel: SwiftUI's DatePicker has no minute interval.
private struct TimeWheel: UIViewRepresentable {
    @Binding var date: Date

    func makeUIView(context: Context) -> UIDatePicker {
        let p = UIDatePicker()
        p.datePickerMode = .time
        p.preferredDatePickerStyle = .wheels
        p.minuteInterval = 5
        p.locale = Locale(identifier: "ko_KR")
        p.overrideUserInterfaceStyle = .dark
        p.setContentHuggingPriority(.defaultLow, for: .horizontal)
        p.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)), for: .valueChanged)
        return p
    }

    func updateUIView(_ p: UIDatePicker, context: Context) {
        if p.date != date { p.date = date }
    }

    func makeCoordinator() -> Coordinator { Coordinator(date: $date) }

    final class Coordinator: NSObject {
        var date: Binding<Date>
        init(date: Binding<Date>) { self.date = date }
        @objc func changed(_ p: UIDatePicker) { date.wrappedValue = p.date }
    }
}
