import Foundation
import Observation
import UserNotifications

@MainActor
@Observable
final class NotificationService {
    private let center: UNUserNotificationCenter
    private let calendar: Calendar

    var authorizationStatus: UNAuthorizationStatus = .notDetermined

    init(center: UNUserNotificationCenter = .current(), calendar: Calendar = .current) {
        self.center = center
        self.calendar = calendar
    }

    @discardableResult
    func refreshAuthorizationStatus() async -> UNAuthorizationStatus {
        let settings = await center.notificationSettings()
        authorizationStatus = settings.authorizationStatus
        return settings.authorizationStatus
    }

    @discardableResult
    func requestAuthorizationIfNeeded() async -> Bool {
        let status = await refreshAuthorizationStatus()

        switch status {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .sound])
                await refreshAuthorizationStatus()
                return granted
            } catch {
                #if DEBUG
                print("Grow: notification authorization failed: \(error)")
                #endif
                return false
            }
        @unknown default:
            return false
        }
    }

    func scheduleCaptureReminder(for grow: Grow, species: PlantSpecies?) async {
        guard await requestAuthorizationIfNeeded() else { return }

        let identifier = captureReminderIdentifier(for: grow)
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let nextDayIndex = max(grow.dayCount + 1, (grow.photos ?? []).count + 1)
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: nextReminderComponents(),
            repeats: false
        )
        let request = UNNotificationRequest(
            identifier: identifier,
            content: captureReminderContent(dayIndex: nextDayIndex, species: species, grow: grow),
            trigger: trigger
        )

        do {
            try await center.add(request)
        } catch {
            #if DEBUG
            print("Grow: capture reminder scheduling failed: \(error)")
            #endif
        }
    }

    func cancelCaptureReminder(for grow: Grow) {
        center.removePendingNotificationRequests(withIdentifiers: [captureReminderIdentifier(for: grow)])
    }

    private func captureReminderIdentifier(for grow: Grow) -> String {
        "capture-reminder-\(grow.id.uuidString)"
    }

    private func nextReminderComponents() -> DateComponents {
        let now = Date()
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now
        var components = calendar.dateComponents([.year, .month, .day], from: tomorrow)
        components.hour = 9
        components.minute = 0
        components.second = 0
        components.calendar = calendar
        return components
    }

    private func captureReminderContent(dayIndex: Int, species: PlantSpecies?, grow: Grow) -> UNMutableNotificationContent {
        let plantName = grow.nickname.isEmpty ? (species?.commonName ?? "your plant") : grow.nickname
        let content = UNMutableNotificationContent()
        content.title = "Day \(dayIndex) frame is ready"
        content.body = reminderBody(dayIndex: dayIndex, plantName: plantName)
        content.sound = .default
        content.userInfo = [
            "destination": "capture",
            "growID": grow.id.uuidString
        ]
        return content
    }

    private func reminderBody(dayIndex: Int, plantName: String) -> String {
        switch dayIndex {
        case 1...2:
            "No visible change is normal. Snap one steady frame so \(plantName)'s future reel has a true beginning."
        case 3...7:
            "First-week growth is quiet. Today's frame keeps \(plantName)'s reveal building."
        default:
            "Keep the angle steady and add today's frame to \(plantName)'s reel."
        }
    }
}
