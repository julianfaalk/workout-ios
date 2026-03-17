import SwiftUI
import UIKit
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif
import UserNotifications

final class WorkoutAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
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
}

@main
struct WorkoutAppApp: App {
    @UIApplicationDelegateAdaptor(WorkoutAppDelegate.self) private var appDelegate
    @StateObject private var workoutViewModel = WorkoutViewModel()
    @StateObject private var sessionViewModel = AppSessionViewModel()
    @StateObject private var storeManager = StoreManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(workoutViewModel)
                .environmentObject(sessionViewModel)
                .environmentObject(storeManager)
                .onOpenURL { url in
                    if url.scheme == AppConfig.appScheme {
                        Task {
                            await sessionViewModel.handleIncomingURL(url)
                        }
                    } else {
                        #if canImport(GoogleSignIn)
                        GIDSignIn.sharedInstance.handle(url)
                        #endif
                    }
                }
        }
    }
}
