import SwiftUI

// MARK: - macOS ContentView with custom sidebar
struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 220, ideal: 220)
        } detail: {
            DetailView()
        }
        .frame(minWidth: 1200, minHeight: 800)
    }
}

// MARK: - Sidebar
private struct SidebarView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Eunoia")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.primary)
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 12)

            Divider()
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

            VStack(spacing: 4) {
                SidebarItem(
                    icon: "house",
                    title: "首页",
                    isSelected: appState.selectedTab == .home
                ) {
                    appState.selectedTab = .home
                }

                SidebarItem(
                    icon: "waveform",
                    title: "转录",
                    isSelected: appState.selectedTab == .transcription
                ) {
                    appState.selectedTab = .transcription
                }

                SidebarItem(
                    icon: "character.bubble",
                    title: "翻译",
                    isSelected: appState.selectedTab == .translation
                ) {
                    appState.selectedTab = .translation
                }

                SidebarItem(
                    icon: "book.fill",
                    title: "生词本",
                    isSelected: appState.selectedTab == .vocabulary
                ) {
                    appState.selectedTab = .vocabulary
                }

                SidebarItem(
                    icon: "gearshape.fill",
                    title: "设置",
                    isSelected: appState.selectedTab == .settings
                ) {
                    appState.selectedTab = .settings
                }
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()
        }
        .background(Color.white)
    }
}

// MARK: - Sidebar Item
private struct SidebarItem: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .frame(width: 20)

                Text(title)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .medium))

                Spacer()
            }
            .foregroundColor(isSelected ? .white : .secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(isSelected ? Color.accentColor : Color.clear)
            .cornerRadius(8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Detail View
private struct DetailView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        switch appState.selectedTab {
        case .home:
            HomeView()
        case .transcription:
            TranscriptionView()
        case .translation:
            TranslationView()
        case .vocabulary:
            VocabularyListView()
        case .settings:
            SettingsAndReviewView()
        }
    }
}
