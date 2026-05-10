import SwiftUI
import Photos
import UserNotifications

@main
struct SpeakingEnglishApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .task {
                    await requestPermissionsSequentially()
                }
        }
    }

    /// 首次启动依次请求权限
    private func requestPermissionsSequentially() async {
        let hasRequested = UserDefaults.standard.bool(forKey: "permissions_requested")
        guard !hasRequested else { return }

        // 1. 通知权限
        let notificationCenter = UNUserNotificationCenter.current()
        let granted = try? await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
        print("通知权限: \(granted == true ? "已授权" : "已拒绝")")

        // 2. 相册权限（iOS 14+）
        if #available(iOS 14, *) {
            let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            print("相册权限: \(status == .authorized || status == .limited ? "已授权" : "已拒绝")")
        }

        UserDefaults.standard.set(true, forKey: "permissions_requested")
    }
}

class AppState: ObservableObject {
    @Published var selectedTab: Tab = .home

    enum Tab {
        case home
        case transcription
        case translation
        case vocabulary
        case settings
    }
}
