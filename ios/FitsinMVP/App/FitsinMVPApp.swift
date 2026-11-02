import SwiftUI
import UserNotifications
import GoogleSignIn

@main
struct FitsinMVPApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var session = AppSession()
    @StateObject private var calendarAuth = CalendarAuthManager()

    init() {
        if !Self.workspaceEnabled { Task { await APIClient.shared.warmUp() } }
    }

    static var workspaceEnabled: Bool { (Bundle.main.object(forInfoDictionaryKey: "NATIVE_WORKSPACE_ENABLED") as? String) == "YES" }

    var body: some Scene {
        WindowGroup {
            Group {
                if Self.workspaceEnabled {
                    WorkspaceRoot()
                        .onAppear { CalendarService.shared.authManager = calendarAuth }
                        .environmentObject(session)
                        .environmentObject(calendarAuth)
                } else if session.isFullyAuthenticated {
                    RootTabView()
                        .environmentObject(session)
                        .environmentObject(calendarAuth)
                        .onAppear {
                            requestPushPermission()
                            CalendarService.shared.authManager = calendarAuth
                            Task { await calendarAuth.restorePreviousSignIn() }
                        }
                } else if session.userName != nil && !session.pinVerified {
                    PinLockView()
                        .environmentObject(session)
                } else {
                    UserNameView()
                        .environmentObject(session)
                }
            }
        }
    }

    private func requestPushPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            print("[push] Permission granted: \(granted), error: \(String(describing: error))")
            if granted {
                DispatchQueue.main.async {
                    print("[push] Registering for remote notifications...")
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
    }
}
