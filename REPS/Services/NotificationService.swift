import Foundation
import UserNotifications
import UIKit

extension Notification.Name {
    static let workoutAPNsTokenDidChange = Notification.Name("workout.apnsTokenDidChange")
}

final class NotificationService {
    static let shared = NotificationService()

    private let apnsTokenKey = "workout.push.apnsToken"
    private let deviceIDKey = "workout.push.deviceId"
    private let languageKey = "workout.localization.selectedLanguage"

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

    func currentPermissionStatus() async -> String {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return "authorized"
        case .denied:
            return "denied"
        case .notDetermined:
            return "not_determined"
        @unknown default:
            return "not_determined"
        }
    }

    func handleRemoteNotificationDeviceToken(_ tokenData: Data) {
        let token = tokenData.map { String(format: "%02.2hhx", $0) }.joined()
        UserDefaults.standard.set(token, forKey: apnsTokenKey)
        print("APNs token stored: \(token)")
        NotificationCenter.default.post(name: .workoutAPNsTokenDidChange, object: nil)
    }

    func handleRemoteNotificationRegistrationFailure(_ error: Error) {
        print("APNs registration failed: \(error.localizedDescription)")
    }

    var currentAPNsToken: String? {
        UserDefaults.standard.string(forKey: apnsTokenKey)
    }

    var currentDeviceID: String {
        if let stored = UserDefaults.standard.string(forKey: deviceIDKey), !stored.isEmpty {
            return stored
        }
        let newValue = UUID().uuidString.lowercased()
        UserDefaults.standard.set(newValue, forKey: deviceIDKey)
        return newValue
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
        let language = normalizedLanguageCode()
        switch goalFocus {
        case .strength:
            switch language {
            case "de": return "Schwer heben: \(template.name)"
            case "es": return "Levanta pesado: \(template.name)"
            case "ar": return "ارفع بثقل: \(template.name)"
            case "hi": return "भारी उठाओ: \(template.name)"
            case "zh-Hans": return "重训开始：\(template.name)"
            default: return "Lift heavy: \(template.name)"
            }
        case .recomposition:
            switch language {
            case "de": return "Bleib lean mit \(template.name)"
            case "es": return "Mantente definido con \(template.name)"
            case "ar": return "حافظ على الرشاقة مع \(template.name)"
            case "hi": return "लीन रहो: \(template.name)"
            case "zh-Hans": return "保持精瘦：\(template.name)"
            default: return "Stay lean with \(template.name)"
            }
        case .athletic:
            switch language {
            case "de": return "Performance Block: \(template.name)"
            case "es": return "Bloque de rendimiento: \(template.name)"
            case "ar": return "كتلة الأداء: \(template.name)"
            case "hi": return "परफॉर्मेंस ब्लॉक: \(template.name)"
            case "zh-Hans": return "表现训练：\(template.name)"
            default: return "Performance block: \(template.name)"
            }
        case .hypertrophy, .none:
            switch language {
            case "de": return "Zeit zu wachsen: \(template.name)"
            case "es": return "Hora de crecer: \(template.name)"
            case "ar": return "وقت النمو: \(template.name)"
            case "hi": return "मसल ग्रोथ का समय: \(template.name)"
            case "zh-Hans": return "增肌时间：\(template.name)"
            default: return "Time to grow: \(template.name)"
            }
        }
    }

    private func reminderBody(for day: ScheduleDay, goalFocus: TrainingGoalFocus?) -> String {
        let language = normalizedLanguageCode()
        switch goalFocus {
        case .strength:
            switch language {
            case "de": return "\(day.dayName) steht. Triff deine Anker und bewege die Zahlen."
            case "es": return "\(day.dayName) ya esta listo. Cumple tus basicos y mueve los numeros."
            case "ar": return "تم تثبيت \(day.dayName). اضرب الأساسيات وحرّك الأرقام."
            case "hi": return "\(day.dayName) तय है। अपने मुख्य लिफ्ट मारो और नंबर आगे बढ़ाओ।"
            case "zh-Hans": return "\(day.dayName) 已安排好。拿下核心动作，把数据推上去。"
            default: return "\(day.dayName) is locked in. Hit your anchors and move the numbers."
            }
        case .recomposition:
            switch language {
            case "de": return "\(day.dayName) ist bereit. Halt den Streak am Leben und bleib sharp."
            case "es": return "\(day.dayName) esta en cubierta. Mantén la racha y sigue fino."
            case "ar": return "\(day.dayName) جاهز. حافظ على السلسلة وابقَ حادًا."
            case "hi": return "\(day.dayName) तैयार है। स्ट्रीक जिंदा रखो और फोकस में रहो।"
            case "zh-Hans": return "\(day.dayName) 已准备好。保持连胜，继续稳住状态。"
            default: return "\(day.dayName) is on deck. Keep the streak alive and stay sharp."
            }
        case .athletic:
            switch language {
            case "de": return "\(day.dayName) ist ready. Trainier explosiv, kontrolliert und konstant."
            case "es": return "\(day.dayName) esta listo. Entrena con potencia, control y constancia."
            case "ar": return "\(day.dayName) جاهز. تدرب بانفجار وتحكم وثبات."
            case "hi": return "\(day.dayName) तैयार है। विस्फोटक, कंट्रोल्ड और लगातार ट्रेन करो।"
            case "zh-Hans": return "\(day.dayName) 已准备好。爆发、控制、稳定地训练。"
            default: return "\(day.dayName) is ready. Train explosive, controlled and consistent."
            }
        case .hypertrophy, .none:
            switch language {
            case "de": return "\(day.dayName) ist bereit. Jage saubere Reps, Volumen und Momentum."
            case "es": return "\(day.dayName) esta listo. Ve por reps limpias, volumen y momentum."
            case "ar": return "\(day.dayName) جاهز. طارد التكرارات النظيفة والحجم والزخم."
            case "hi": return "\(day.dayName) तैयार है। साफ रेप्स, वॉल्यूम और मोमेंटम के पीछे जाओ।"
            case "zh-Hans": return "\(day.dayName) 已准备好。追求干净次数、训练量和节奏。"
            default: return "\(day.dayName) is ready. Chase clean reps, volume and momentum."
            }
        }
    }

    // MARK: - Rest Timer

    func scheduleRestTimerNotification(duration: Int) {
        let center = UNUserNotificationCenter.current()

        // Cancel any existing rest timer notification
        center.removePendingNotificationRequests(withIdentifiers: ["rest_timer"])

        let content = UNMutableNotificationContent()
        let restCopy = localizedRestTimerCopy()
        content.title = restCopy.title
        content.body = restCopy.body
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

    private func localizedRestTimerCopy() -> (title: String, body: String) {
        switch normalizedLanguageCode() {
        case "de":
            return ("Pause vorbei", "Zeit fuer deinen naechsten Satz.")
        case "es":
            return ("Descanso completo", "Hora de tu siguiente serie.")
        case "ar":
            return ("انتهت الراحة", "حان وقت المجموعة التالية.")
        case "hi":
            return ("रेस्ट पूरा", "अब अगला सेट शुरू करो।")
        case "zh-Hans":
            return ("休息结束", "该开始下一组了。")
        default:
            return ("Rest Complete", "Time for your next set!")
        }
    }

    private func normalizedLanguageCode() -> String {
        let rawValue = UserDefaults.standard.string(forKey: languageKey)
            ?? Locale.preferredLanguages.first
            ?? "en"
        let normalized = rawValue.lowercased()

        if normalized.hasPrefix("de") {
            return "de"
        }
        if normalized.hasPrefix("es") {
            return "es"
        }
        if normalized.hasPrefix("ar") {
            return "ar"
        }
        if normalized.hasPrefix("hi") {
            return "hi"
        }
        if normalized.hasPrefix("zh") {
            return "zh-Hans"
        }
        return "en"
    }
}
