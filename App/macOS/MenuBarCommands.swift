import SwiftUI

#if os(macOS)

struct MenuBarCommands: Commands {
    @FocusedBinding(\.selectedTab) private var selectedTab: AppState.Tab?

    var body: some Commands {
        // File Menu
        CommandMenu("文件") {
            Button("导入视频...") {
                // 触发导入视频通知或事件
                NotificationCenter.default.post(name: .importVideo, object: nil)
            }
            .keyboardShortcut("o", modifiers: .command)

            Divider()

            Button("新建转录任务") {
                NotificationCenter.default.post(name: .newTranscription, object: nil)
            }
            .keyboardShortcut("t", modifiers: [.command, .shift])
        }

        // View Menu
        CommandMenu("视图") {
            Button("首页") {
                selectedTab = .home
            }
            .keyboardShortcut("1", modifiers: .command)

            Button("转录") {
                selectedTab = .transcription
            }
            .keyboardShortcut("2", modifiers: .command)

            Button("翻译") {
                selectedTab = .translation
            }
            .keyboardShortcut("3", modifiers: .command)

            Button("生词本") {
                selectedTab = .vocabulary
            }
            .keyboardShortcut("4", modifiers: .command)

            Button("设置") {
                selectedTab = .settings
            }
            .keyboardShortcut("5", modifiers: .command)
        }

        // Help Menu
        CommandGroup(after: .help) {
            Divider()
            Button("Eunoia 帮助") {
                // 可以打开帮助窗口
            }
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let importVideo = Notification.Name("importVideo")
    static let newTranscription = Notification.Name("newTranscription")
}

// MARK: - Focused Values

struct SelectedTabKey: FocusedValueKey {
    typealias Value = Binding<AppState.Tab>
}

extension FocusedValues {
    var selectedTab: Binding<AppState.Tab>? {
        get { self[SelectedTabKey.self] }
        set { self[SelectedTabKey.self] = newValue }
    }
}

#endif
