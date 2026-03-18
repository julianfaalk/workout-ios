import SwiftUI
import UIKit
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif
import UserNotifications

final class REPSDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        NotificationService.shared.handleRemoteNotificationDeviceToken(deviceToken)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        NotificationService.shared.handleRemoteNotificationRegistrationFailure(error)
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if let deepLink = response.notification.request.content.userInfo["deepLink"] as? String,
           let url = URL(string: deepLink) {
            Task { @MainActor in
                UIApplication.shared.open(url)
            }
        }
        completionHandler()
    }
}

@main
struct REPSApp: App {
    @UIApplicationDelegateAdaptor(REPSDelegate.self) private var appDelegate
    @StateObject private var workoutViewModel = WorkoutViewModel()
    @StateObject private var sessionViewModel = AppSessionViewModel()
    @StateObject private var storeManager = StoreManager.shared
    @StateObject private var localization = LocalizationService.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(workoutViewModel)
                .environmentObject(sessionViewModel)
                .environmentObject(storeManager)
                .environmentObject(localization)
                .environment(\.locale, localization.locale)
                .environment(\.layoutDirection, localization.layoutDirection)
                .onOpenURL { url in
                    if url.scheme != AppConfig.appScheme {
                        #if canImport(GoogleSignIn)
                        GIDSignIn.sharedInstance.handle(url)
                        #endif
                    }
                    Task {
                        await sessionViewModel.handleIncomingURL(url)
                    }
                }
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                    guard let url = activity.webpageURL else { return }
                    Task {
                        await sessionViewModel.handleIncomingURL(url)
                    }
                }
        }
    }
}
