import SwiftUI
import UniformTypeIdentifiers

struct TranslationView: View {
    @StateObject private var translationManager = TranslationTaskManager.shared
    @State private var showSubtitlePicker = false
    @State private var selectedSubtitleURL: URL?
    @State private var selectedSubtitleMode: SubtitleMode = .chinese
    @State private var selectedTaskID: UUID?

    private var selectedTask: TranslationTask? {
        translationManager.tasks.first { $0.id == selectedTaskID }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("翻译")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(Color(hex: "1D1D1F"))

                // 字幕翻译卡片
                translateCard

                // 翻译任务列表
                if !translationManager.tasks.isEmpty {
                    tasksSection
                }

                // 空状态
                if translationManager.tasks.isEmpty && selectedSubtitleURL == nil {
                    emptyState
                }
            }
            .padding(32)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(hex: "F5F5F7"))
        .sheet(isPresented: Binding(
            get: { selectedTask != nil },
            set: { if !$0 { selectedTaskID = nil } }
        )) {
            if let task = selectedTask {
                TranslationTaskDetailView(task: task)
            }
        }
        .sheet(isPresented: $showSubtitlePicker) {
            SubtitlePickerView { url in
                selectedSubtitleURL = url
                showSubtitlePicker = false
            }
        }
    }

    // MARK: - 字幕翻译卡片
    private var translateCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("字幕翻译")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color(hex: "1D1D1F"))

            if let url = selectedSubtitleURL {
                selectedFileRow(url: url)

                subtitleModeSelector

                startButton
            } else {
                uploadArea
            }

            Text(subtitleFooterText)
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "8E8E93"))
        }
        .padding(24)
        .background(Color.white)
        .cornerRadius(16)
    }

    // MARK: - 上传区域
    private var uploadArea: some View {
        Button(action: { showSubtitlePicker = true }) {
            VStack(spacing: 12) {
                Image(systemName: "doc.text")
                    .font(.system(size: 36))
                    .foregroundColor(Color(hex: "FF9500"))

                Text("选择字幕文件")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "6E6E73"))

                Text("支持 SRT、ASS 格式")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "8E8E93"))
            }
            .frame(maxWidth: .infinity, minHeight: 180)
            .background(Color(hex: "F5F5F7"))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(hex: "E5E5EA"), lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 已选文件行
    private func selectedFileRow(url: URL) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 18))
                .foregroundColor(Color(hex: "FF9500"))

            Text(url.lastPathComponent)
                .font(.system(size: 15))
                .foregroundColor(Color(hex: "1D1D1F"))
                .lineLimit(1)

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18))
                .foregroundColor(Color(hex: "34C759"))

            Button(action: { selectedSubtitleURL = nil }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(Color(hex: "8E8E93"))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color(hex: "F5F5F7"))
        .cornerRadius(12)
    }

    // MARK: - 字幕模式选择器
    private var subtitleModeSelector: some View {
        HStack(spacing: 16) {
            Text("字幕模式")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color(hex: "3A3A3C"))

            HStack(spacing: 0) {
                modeButton(.chinese, label: "中文")
                modeButton(.bilingual, label: "双语")
            }
            .padding(4)
            .background(Color(hex: "F5F5F7"))
            .cornerRadius(8)

            Spacer()
        }
    }

    private func modeButton(_ mode: SubtitleMode, label: String) -> some View {
        Button(action: { selectedSubtitleMode = mode }) {
            Text(label)
                .font(.system(size: 13, weight: selectedSubtitleMode == mode ? .semibold : .regular))
                .foregroundColor(selectedSubtitleMode == mode ? Color(hex: "007AFF") : Color(hex: "6E6E73"))
                .frame(width: 80, height: 32)
                .background(selectedSubtitleMode == mode ? Color.white : Color.clear)
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }

    // MARK: - 开始按钮
    private var startButton: some View {
        Button(action: { startTranslation() }) {
            HStack(spacing: 8) {
                Image(systemName: "character.bubble")
                    .font(.system(size: 14))
                Text("开始翻译")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(Color(hex: "007AFF"))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }

    // MARK: - 任务列表区域
    private var tasksSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("翻译任务")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color(hex: "1D1D1F"))

                Spacer()

                Menu {
                    Button("清空已完成", role: .destructive) {
                        translationManager.clearFinishedTasks()
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 18))
                        .foregroundColor(Color(hex: "6E6E73"))
                }
            }

            ForEach(translationManager.tasks) { task in
                TranslationTaskCard(task: task)
                    .onTapGesture {
                        selectedTaskID = task.id
                    }
                    .contextMenu {
                        if task.status == .completed, let resultPath = task.resultPath {
                            ShareLink(item: URL(fileURLWithPath: resultPath)) {
                                Label("导出字幕", systemImage: "square.and.arrow.up")
                            }
                        }

                        Button {
                            selectedTaskID = task.id
                        } label: {
                            Label("查看详情", systemImage: "info.circle")
                        }

                        Divider()

                        Button(role: .destructive) {
                            translationManager.deleteTask(task.id)
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    }
            }
        }
    }

    // MARK: - 空状态
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "character.bubble")
                .font(.system(size: 50))
                .foregroundColor(Color(hex: "C7C7CC"))

            Text("暂无翻译任务")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color(hex: "8E8E93"))

            Text("选择字幕文件开始翻译")
                .font(.system(size: 13))
                .foregroundColor(Color(hex: "C7C7CC"))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private var subtitleFooterText: String {
        if selectedSubtitleURL == nil {
            return "选择 SRT、ASS 格式字幕文件"
        }
        switch selectedSubtitleMode {
        case .chinese:
            return "翻译为中文，用中文替换原文"
        case .bilingual:
            return "翻译为中文，同时保留原文"
        default:
            return ""
        }
    }

    private func startTranslation() {
        guard let url = selectedSubtitleURL else { return }

        translationManager.startTranslation(
            sourcePath: url.path,
            entryCount: 0,
            subtitleMode: selectedSubtitleMode
        )

        selectedSubtitleURL = nil
    }
}

// MARK: - 翻译任务卡片
private struct TranslationTaskCard: View {
    let task: TranslationTask

    var body: some View {
        HStack(spacing: 16) {
            statusIcon
                .frame(width: 44, height: 44)
                .background(statusIconBackground)
                .cornerRadius(12)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(task.sourcePath.split(separator: "/").last.map(String.init) ?? "字幕文件")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color(hex: "1D1D1F"))
                        .lineLimit(1)

                    modeBadge

                    Spacer()
                }

                if task.status == .inProgress {
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(hex: "E5E5EA"))
                            .frame(height: 4)

                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(hex: "007AFF"))
                            .frame(width: max(4, 200 * CGFloat(task.progress)), height: 4)
                    }
                    .frame(maxWidth: 200)
                }

                Text(task.statusMessage)
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "8E8E93"))
            }

            Spacer()

            Text(task.createdAt.formatted(date: .abbreviated, time: .shortened))
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "C7C7CC"))
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(16)
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch task.status {
        case .inProgress:
            Image(systemName: "character.bubble")
                .font(.system(size: 18))
                .foregroundColor(Color(hex: "007AFF"))
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18))
                .foregroundColor(Color(hex: "34C759"))
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 18))
                .foregroundColor(Color(hex: "FF3B30"))
        case .queued, .cancelled:
            Image(systemName: "clock")
                .font(.system(size: 18))
                .foregroundColor(Color(hex: "8E8E93"))
        }
    }

    private var statusIconBackground: Color {
        switch task.status {
        case .inProgress:
            return Color(hex: "EEF2FF")
        case .completed:
            return Color(hex: "E8F5E9")
        case .failed:
            return Color(hex: "FEE2E2")
        case .queued, .cancelled:
            return Color(hex: "F5F5F7")
        }
    }

    @ViewBuilder
    private var modeBadge: some View {
        if task.subtitleMode == .bilingual {
            Text("双语")
                .font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color(hex: "FFF3E0"))
                .foregroundColor(Color(hex: "FF9500"))
                .cornerRadius(4)
        } else {
            Text("中文")
                .font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color(hex: "E3F2FD"))
                .foregroundColor(Color(hex: "007AFF"))
                .cornerRadius(4)
        }
    }
}

// MARK: - Translation Task Detail

struct TranslationTaskDetailView: View {
    let task: TranslationTask
    @Environment(\.dismiss) private var dismiss
    @State private var translatedContent: String?

    var body: some View {
        NavigationStack {
            List {
                Section("状态") {
                    LabeledContent("任务状态", value: task.status.rawValue)
                    LabeledContent("创建时间", value: task.createdAt.formatted())
                    if let completedAt = task.completedAt {
                        LabeledContent("完成时间", value: completedAt.formatted())
                    }
                }

                if task.status == .failed, let error = task.errorMessage {
                    Section("错误信息") {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }

                if task.status == .inProgress {
                    Section("进度") {
                        VStack(alignment: .leading, spacing: 8) {
                            ProgressView(value: task.progress)
                                .tint(.cyan)
                            Text(task.statusMessage)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                if task.status == .completed, let resultPath = task.resultPath {
                    Section("翻译结果") {
                        if let content = translatedContent {
                            ScrollView {
                                Text(content)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(height: 300)
                        } else {
                            Text("加载中...")
                                .foregroundColor(.secondary)
                        }

                        ShareLink(item: URL(fileURLWithPath: resultPath)) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                    .foregroundColor(.blue)
                                Text("分享/下载字幕")
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle("翻译任务")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadTranslatedContent()
            }
        }
    }

    private func loadTranslatedContent() {
        guard let resultPath = task.resultPath else { return }
        do {
            translatedContent = try String(contentsOfFile: resultPath, encoding: .utf8)
        } catch {
            translatedContent = "读取失败: \(error.localizedDescription)"
        }
    }
}

#Preview {
    TranslationView()
}
