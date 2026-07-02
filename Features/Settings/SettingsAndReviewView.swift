import SwiftUI

enum SettingsTab {
    case settings
    case review
}

struct SettingsAndReviewView: View {
    @State private var selectedTab: SettingsTab = .settings
    @State private var statistics: LearningStatistics?
    @State private var showingResetConfirmation: Bool = false
    @State private var showingAboutSheet: Bool = false
    @State private var showingHelpSheet: Bool = false
    @StateObject private var reviewViewModel = ReviewViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 标题 + 分段控制器
                HStack {
                    Text("设置")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Color(hex: "1D1D1F"))

                    Spacer()

                    // 分段控制器
                    HStack(spacing: 0) {
                        tabButton(.settings, label: "设置")
                        tabButton(.review, label: "复习")
                    }
                    .padding(4)
                    .background(Color(hex: "F5F5F7"))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(hex: "E5E5EA"), lineWidth: 1)
                    )
                }

                if selectedTab == .settings {
                    settingsContent
                } else {
                    reviewContent
                }
            }
            .padding(32)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(hex: "F5F5F7"))
        .sheet(isPresented: $showingAboutSheet) {
            AboutView()
        }
        .sheet(isPresented: $showingHelpSheet) {
            HelpView()
        }
        .onAppear {
            loadStatistics()
        }
    }

    private func tabButton(_ tab: SettingsTab, label: String) -> some View {
        Button(action: { selectedTab = tab }) {
            Text(label)
                .font(.system(size: 13, weight: selectedTab == tab ? .semibold : .regular))
                .foregroundColor(selectedTab == tab ? Color(hex: "007AFF") : Color(hex: "6E6E73"))
                .frame(width: 70, height: 32)
                .background(selectedTab == tab ? Color.white : Color.clear)
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Settings Content

    private var settingsContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 学习统计卡片
            if let stats = statistics {
                statsCard(stats)
            }

            // 信息卡片
            infoCard

            // 数据管理卡片
            dataCard
        }
    }

    private func statsCard(_ stats: LearningStatistics) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("学习统计")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color(hex: "1D1D1F"))

            HStack(spacing: 0) {
                statItem(value: "\(stats.totalWords)", label: "总单词数", color: "007AFF")
                Divider()
                    .frame(height: 40)
                statItem(value: "\(stats.wordsToReview)", label: "待复习", color: "FF9500")
                Divider()
                    .frame(height: 40)
                statItem(value: "\(stats.reviewedToday)", label: "今日已学", color: "34C759")
            }
        }
        .padding(24)
        .background(Color.white)
        .cornerRadius(16)
    }

    private func statItem(value: String, label: String, color: String) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(Color(hex: color))

            Text(label)
                .font(.system(size: 13))
                .foregroundColor(Color(hex: "8E8E93"))
        }
        .frame(maxWidth: .infinity)
    }

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("信息")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color(hex: "1D1D1F"))
                .padding(.bottom, 12)

            VStack(spacing: 0) {
                Button(action: { showingAboutSheet = true }) {
                    HStack(spacing: 12) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 18))
                            .foregroundColor(Color(hex: "007AFF"))
                            .frame(width: 28)

                        Text("关于应用")
                            .font(.system(size: 15))
                            .foregroundColor(Color(hex: "1D1D1F"))

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "C7C7CC"))
                    }
                    .padding(.vertical, 14)
                }
                .buttonStyle(.plain)

                Divider()
                    .padding(.leading, 40)

                Button(action: { showingHelpSheet = true }) {
                    HStack(spacing: 12) {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 18))
                            .foregroundColor(Color(hex: "FF9500"))
                            .frame(width: 28)

                        Text("使用帮助")
                            .font(.system(size: 15))
                            .foregroundColor(Color(hex: "1D1D1F"))

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "C7C7CC"))
                    }
                    .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(24)
        .background(Color.white)
        .cornerRadius(16)
    }

    private var dataCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("数据管理")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color(hex: "1D1D1F"))

            Button(action: { showingResetConfirmation = true }) {
                HStack(spacing: 12) {
                    Image(systemName: "trash")
                        .font(.system(size: 18))
                        .foregroundColor(Color(hex: "FF3B30"))
                        .frame(width: 28)

                    Text("重置所有数据")
                        .font(.system(size: 15))
                        .foregroundColor(Color(hex: "FF3B30"))

                    Spacer()
                }
                .padding(.vertical, 14)
            }
            .buttonStyle(.plain)

            Text("此操作将删除所有单词和复习记录，且无法恢复。")
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "8E8E93"))
        }
        .padding(24)
        .background(Color.white)
        .cornerRadius(16)
        .confirmationDialog("确认重置", isPresented: $showingResetConfirmation) {
            Button("重置所有数据", role: .destructive) {
                resetAllData()
            }
            Button("取消", role: .cancel) { }
        } message: {
            Text("确定要删除所有数据吗？此操作不可撤销。")
        }
    }

    // MARK: - Review Content

    private var reviewContent: some View {
        Group {
            if reviewViewModel.isLoading {
                ProgressView("加载中...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if reviewViewModel.wordsToReview.isEmpty {
                EmptyReviewView()
            } else if reviewViewModel.isCompleted {
                ReviewCompletedView(
                    reviewedCount: reviewViewModel.reviewedCount,
                    onStartAgain: { reviewViewModel.startReview() }
                )
            } else if let currentWord = reviewViewModel.currentWord {
                ReviewCardView(
                    word: currentWord,
                    progress: reviewViewModel.progress,
                    onRate: { quality in
                        reviewViewModel.rateWord(quality: quality)
                    }
                )
            }
        }
        .onAppear {
            reviewViewModel.startReview()
        }
    }

    // MARK: - Actions

    private func loadStatistics() {
        do {
            statistics = try VocabularyService.shared.getStatistics()
        } catch {
            print("Failed to load statistics: \(error)")
        }
    }

    private func resetAllData() {
        print("Reset all data requested")
    }
}

// MARK: - Empty Review View

struct EmptyReviewView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(Color(hex: "34C759"))

            Text("太棒了！")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(Color(hex: "1D1D1F"))

            Text("目前没有需要复习的单词")
                .font(.body)
                .foregroundColor(Color(hex: "8E8E93"))

            Text("继续学习更多单词吧")
                .font(.caption)
                .foregroundColor(Color(hex: "C7C7CC"))
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Review Completed View

struct ReviewCompletedView: View {
    let reviewedCount: Int
    let onStartAgain: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "star.fill")
                .font(.system(size: 60))
                .foregroundColor(Color(hex: "FFCC00"))

            Text("复习完成！")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(Color(hex: "1D1D1F"))

            Text("已复习 \(reviewedCount) 个单词")
                .font(.body)
                .foregroundColor(Color(hex: "8E8E93"))

            Button(action: onStartAgain) {
                Text("再复习一次")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(Color(hex: "007AFF"))
                    .cornerRadius(12)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: 200)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Review Card View

struct ReviewCardView: View {
    let word: VocabularyEntry
    let progress: (current: Int, total: Int)
    let onRate: (Int) -> Void

    @State private var showingAnswer: Bool = false

    var body: some View {
        VStack(spacing: 24) {
            // Progress indicator
            HStack {
                Text("进度: \(progress.current)/\(progress.total)")
                    .font(.caption)
                    .foregroundColor(Color(hex: "8E8E93"))

                Spacer()

                if let nextReview = word.lastReviewDate {
                    Text("上次: \(nextReview, style: .relative)")
                        .font(.caption)
                        .foregroundColor(Color(hex: "8E8E93"))
                }
            }

            Spacer()

            // Word card
            VStack(spacing: 16) {
                Text(word.word)
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(Color(hex: "1D1D1F"))

                if showingAnswer {
                    if let meaning = word.meaning, !meaning.isEmpty {
                        Text(meaning)
                            .font(.title3)
                            .foregroundColor(Color(hex: "6E6E73"))
                            .transition(.opacity)
                    }

                    if let context = word.context, !context.isEmpty {
                        Text(context)
                            .font(.caption)
                            .foregroundColor(Color(hex: "8E8E93"))
                            .lineLimit(3)
                            .padding(.top, 8)
                    }
                } else {
                    Text("点击查看答案")
                        .font(.caption)
                        .foregroundColor(Color(hex: "8E8E93"))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(32)
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)

            Spacer()

            // Action buttons
            VStack(spacing: 12) {
                if !showingAnswer {
                    Button(action: { withAnimation { showingAnswer = true } }) {
                        Text("显示答案")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(hex: "007AFF"))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                } else {
                    Text("回忆程度如何？")
                        .font(.caption)
                        .foregroundColor(Color(hex: "8E8E93"))

                    HStack(spacing: 8) {
                        ForEach(SM2Algorithm.Quality.allCases, id: \.rawValue) { quality in
                            Button(action: { onRate(quality.rawValue) }) {
                                Text(quality.displayName)
                                    .font(.caption)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(qualityButtonColor(quality))
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .padding(24)
        .background(Color.white)
        .cornerRadius(16)
    }

    private func qualityButtonColor(_ quality: SM2Algorithm.Quality) -> Color {
        switch quality {
        case .forgotten:
            return Color(hex: "FF3B30")
        case .hard:
            return Color(hex: "FF9500")
        case .difficult:
            return Color(hex: "FFCC00")
        case .good:
            return Color(hex: "34C759")
        case .easy:
            return Color(hex: "34C759")
        case .perfect:
            return Color(hex: "007AFF")
        }
    }
}

// MARK: - About View

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 标题栏
                HStack {
                    Text("关于应用")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Color(hex: "1D1D1F"))

                    Spacer()

                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(Color(hex: "C7C7CC"))
                    }
                    .buttonStyle(.plain)
                }

                VStack(spacing: 16) {
                    Image(systemName: "book.and.wizard")
                        .font(.system(size: 60))
                        .foregroundColor(Color(hex: "007AFF"))

                    Text("Eunoia")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(Color(hex: "1D1D1F"))

                    Text("版本 1.0.0")
                        .font(.caption)
                        .foregroundColor(Color(hex: "8E8E93"))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(Color.white)
                .cornerRadius(16)

                VStack(alignment: .leading, spacing: 16) {
                    Text("介绍")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color(hex: "1D1D1F"))

                    Text("一款帮助你通过视频学习英语的应用。在观看视频时，可以自动提取字幕中的单词，方便学习和复习。")
                        .font(.body)
                        .foregroundColor(Color(hex: "6E6E73"))
                        .lineSpacing(4)
                }
                .padding(24)
                .background(Color.white)
                .cornerRadius(16)
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 16) {
                    Text("Credits")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color(hex: "1D1D1F"))

                    HStack {
                        Text("开发")
                            .font(.body)
                            .foregroundColor(Color(hex: "6E6E73"))
                        Spacer()
                        Text("H2Ocean")
                            .font(.body)
                            .foregroundColor(Color(hex: "1D1D1F"))
                    }

                    Divider()

                    HStack {
                        Text("设计")
                            .font(.body)
                            .foregroundColor(Color(hex: "6E6E73"))
                        Spacer()
                        Text("H2Ocean")
                            .font(.body)
                            .foregroundColor(Color(hex: "1D1D1F"))
                    }
                }
                .padding(24)
                .background(Color.white)
                .cornerRadius(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(32)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(hex: "F5F5F7"))
    }
}

// MARK: - Help View

struct HelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text("使用帮助")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Color(hex: "1D1D1F"))

                    Spacer()

                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(Color(hex: "C7C7CC"))
                    }
                    .buttonStyle(.plain)
                }

                helpCard(
                    icon: "play.rectangle",
                    iconColor: "007AFF",
                    title: "观看视频",
                    description: "在首页选择要学习的视频，观看时字幕会同步显示。"
                )

                helpCard(
                    icon: "hand.tap",
                    iconColor: "FF9500",
                    title: "点击单词",
                    description: "在字幕中点击任意单词，可以将其添加到生词本。"
                )

                helpCard(
                    icon: "brain",
                    iconColor: "34C759",
                    title: "复习记忆",
                    description: "使用 SM-2 间隔重复算法，科学安排复习时间，提高记忆效率。"
                )

                faqSection
            }
            .padding(32)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(hex: "F5F5F7"))
    }

    private func helpCard(icon: String, iconColor: String, title: String, description: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(Color(hex: iconColor))
                .frame(width: 44, height: 44)
                .background(Color(hex: "F5F5F7"))
                .cornerRadius(12)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(hex: "1D1D1F"))

                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "6E6E73"))
                    .lineLimit(nil)
            }

            Spacer()
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(16)
    }

    private var faqSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("常见问题")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color(hex: "1D1D1F"))

            AccordionView(title: "什么是 SM-2 算法？", content: "SM-2 是一种间隔重复算法，由 Piotr Wozniak 发明。它根据你对每个单词的记忆程度，计算最佳复习间隔，帮助你更高效地记忆单词。")

            AccordionView(title: "如何获得示例视频？", content: "将 MP4 格式的视频和对应字幕文件放入 Resources/SampleVideos 目录即可。支持 SRT 和 ASS 格式的字幕文件。")
        }
        .padding(24)
        .background(Color.white)
        .cornerRadius(16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Accordion View

struct AccordionView: View {
    let title: String
    let content: String
    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                HStack {
                    Text(title)
                        .font(.subheadline)
                        .foregroundColor(Color(hex: "1D1D1F"))
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(Color(hex: "8E8E93"))
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                Text(content)
                    .font(.caption)
                    .foregroundColor(Color(hex: "6E6E73"))
                    .padding(.top, 4)
                    .lineSpacing(2)
            }
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    SettingsAndReviewView()
}
