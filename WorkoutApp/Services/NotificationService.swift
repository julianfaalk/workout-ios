import Foundation
import UserNotifications
import UIKit

final class NotificationService {
    static let shared = NotificationService()

    private let apnsTokenKey = "workout.push.apnsToken"

    private init() { }

    // MARK: - Permission

    func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            if granted {
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
            return granted
        } catch {
            print("Notification permission error: \(error)")
            return false
        }
    }

    func checkPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        return settings.authorizationStatus == .authorized
    }

    func handleRemoteNotificationDeviceToken(_ tokenData: Data) {
        let token = tokenData.map { String(format: "%02.2hhx", $0) }.joined()
        UserDefaults.standard.set(token, forKey: apnsTokenKey)
        print("APNs token stored: \(token)")
    }

    func handleRemoteNotificationRegistrationFailure(_ error: Error) {
        print("APNs registration failed: \(error.localizedDescription)")
    }

    var currentAPNsToken: String? {
        UserDefaults.standard.string(forKey: apnsTokenKey)
    }

    // MARK: - Workout Reminders

    func scheduleWorkoutReminders(
        for schedule: [ScheduleDay],
        at time: Date,
        goalFocus: TrainingGoalFocus? = nil
    ) async {
        let center = UNUserNotificationCenter.current()

        // Cancel existing workout reminders
        let identifiers = (0..<7).map { "workout_reminder_\($0)" }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)

        // Schedule new reminders
        for day in schedule where !day.isRestDay {
            guard let template = day.template else { continue }

            let content = UNMutableNotificationContent()
            content.title = reminderTitle(for: template, goalFocus: goalFocus)
            content.body = reminderBody(for: day, goalFocus: goalFocus)
            content.sound = .default
            content.threadIdentifier = "workout-reminders"

            var dateComponents = Calendar.current.dateComponents([.hour, .minute], from: time)
            dateComponents.weekday = day.dayOfWeek + 1 // 1-indexed for UNCalendarNotificationTrigger

            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            let request = UNNotificationRequest(
                identifier: "workout_reminder_\(day.dayOfWeek)",
                content: content,
                trigger: trigger
            )

            do {
                try await center.add(request)
            } catch {
                print("Failed to schedule notification: \(error)")
            }
        }
    }

    func cancelWorkoutReminders() {
        let center = UNUserNotificationCenter.current()
        let identifiers = (0..<7).map { "workout_reminder_\($0)" }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    private func reminderTitle(for template: WorkoutTemplate, goalFocus: TrainingGoalFocus?) -> String {
        switch goalFocus {
        case .strength:
            return "Lift heavy: \(template.name)"
        case .recomposition:
            return "Stay lean with \(template.name)"
        case .athletic:
            return "Performance block: \(template.name)"
        case .hypertrophy, .none:
            return "Time to grow: \(template.name)"
        }
    }

    private func reminderBody(for day: ScheduleDay, goalFocus: TrainingGoalFocus?) -> String {
        switch goalFocus {
        case .strength:
            return "\(day.dayName) is locked in. Hit your anchors and move the numbers."
        case .recomposition:
            return "\(day.dayName) is on deck. Keep the streak alive and stay sharp."
        case .athletic:
            return "\(day.dayName) is ready. Train explosive, controlled and consistent."
        case .hypertrophy, .none:
            return "\(day.dayName) is ready. Chase clean reps, volume and momentum."
        }
    }

    // MARK: - Rest Timer

    func scheduleRestTimerNotification(duration: Int) {
        let center = UNUserNotificationCenter.current()

        // Cancel any existing rest timer notification
        center.removePendingNotificationRequests(withIdentifiers: ["rest_timer"])

        let content = UNMutableNotificationContent()
        content.title = "Rest Complete"
        content.body = "Time for your next set!"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(duration), repeats: false)
        let request = UNNotificationRequest(identifier: "rest_timer", content: content, trigger: trigger)

        center.add(request) { error in
            if let error = error {
                print("Failed to schedule rest timer notification: \(error)")
            }
        }
    }

    func cancelRestTimerNotification() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["rest_timer"])
    }

    // MARK: - Haptic Feedback

    func triggerRestTimerHaptic() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    func triggerPRHaptic() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        // Add extra impact for PR
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            let impact = UIImpactFeedbackGenerator(style: .heavy)
            impact.impactOccurred()
        }
    }
}
