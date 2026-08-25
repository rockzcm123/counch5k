import Foundation
import UserNotifications

enum WorkoutReminderError: LocalizedError {
    case permissionDenied

    var errorDescription: String? {
        L10n.reminderPermissionDenied
    }
}

@MainActor
final class WorkoutReminderScheduler {
    private let center = UNUserNotificationCenter.current()
    private let prefix = "weekly-workout-reminder-"

    func update(
        enabled: Bool,
        weekdays: Set<Int>,
        hour: Int,
        minute: Int
    ) async throws {
        await cancel()
        guard enabled else { return }

        let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        guard granted else { throw WorkoutReminderError.permissionDenied }

        for weekday in weekdays {
            let content = UNMutableNotificationContent()
            content.title = L10n.reminderTitle
            content.body = L10n.reminderBody
            content.sound = .default

            var components = DateComponents()
            components.calendar = .current
            components.weekday = weekday
            components.hour = hour
            components.minute = minute

            let request = UNNotificationRequest(
                identifier: "\(prefix)\(weekday)",
                content: content,
                trigger: UNCalendarNotificationTrigger(
                    dateMatching: components,
                    repeats: true
                )
            )
            try await center.add(request)
        }
    }

    func cancel() async {
        let requests = await center.pendingNotificationRequests()
        let identifiers = requests
            .map(\.identifier)
            .filter { $0.hasPrefix(prefix) }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}
