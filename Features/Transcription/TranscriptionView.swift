import SwiftUI
import UniformTypeIdentifiers

struct TranscriptionView: View {
    @StateObject private var viewModel = TranscriptionViewModel()
    @StateObject private var taskManager = TranscriptionTaskManager.shared
    @State private var showVideoPicker = false
    @State private var showingTaskDetail: TranscriptionTask?
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var toastStyle: ToastView.ToastStyle = .success

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 页面标题
                Text("转录")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(Color(hex: "1D1D1F"))

                // 视频选择卡片
                videoCard

                // 任务列表
                if !taskManager.tasks.isEmpty {
                    tasksSection
                }
            }
            .padding(32)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(hex: "F5F5F7"))
        .sheet(isPresented: $showVideoPicker) {
            DocumentPickerView(
                supportedTypes: [.mpeg4Movie, .quickTimeMovie, .movie],
                pickerMode: .open
            ) { urls in
                if let url = urls.first {
                    viewModel.selectVideo(url: url)
                }
                showVideoPicker = false
            }
        }
        .sheet(item: $showingTaskDetail) { task in
            TaskDetailView(task: task)
        }
        .toast(isPresented: $showToast, message: toastMessage, style: toastStyle)
    }

    // MARK: - 视频选择卡片
    private var videoCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("选择视频")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color(hex: "1D1D1F"))

            // 上传区域 / 已选视频
            if let url = viewModel.selectedVideoURL {
                selectedVideoRow(url: url)
            } else {
                uploadArea
            }

            // 字幕模式选择
            subtitleModeSelector

            // 开始按钮
            startButton
        }
        .padding(24)
        .background(Color.white)
        .cornerRadius(16)
    }

    // MARK: - 上传区域
    private var uploadArea: some View {
        Button(action: { showVideoPicker = true }) {
            VStack(spacing: 12) {
                Image(systemName: "arrow.up.circle")
                    .font(.system(size: 36))
                    .foregroundColor(Color(hex: "007AFF"))

                Text("拖拽视频文件到此处，或点击选择")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "6E6E73"))

                Text("支持 MP4、MOV 格式")
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

    // MARK: - 已选视频行
    private func selectedVideoRow(url: URL) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "film")
                .font(.system(size: 18))
                .foregroundColor(Color(hex: "007AFF"))

            Text(url.lastPathComponent)
                .font(.system(size: 15))
                .foregroundColor(Color(hex: "1D1D1F"))
                .lineLimit(1)

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18))
                .foregroundColor(Color(hex: "34C759"))

            Button(action: { viewModel.clearSelection() }) {
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
                modeButton(.original, label: "原文")
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
        Button(action: { viewModel.subtitleMode = mode }) {
            Text(label)
                .font(.system(size: 13, weight: viewModel.subtitleMode == mode ? .semibold : .regular))
                .foregroundColor(viewModel.subtitleMode == mode ? Color(hex: "007AFF") : Color(hex: "6E6E73"))
                .frame(width: 80, height: 32)
                .background(viewModel.subtitleMode == mode ? Color.white : Color.clear)
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }

    // MARK: - 开始按钮
    private var startButton: some View {
        Button(action: { viewModel.startTranscription() }) {
            HStack(spacing: 8) {
                Image(systemName: "play.fill")
                    .font(.system(size: 14))
                Text("开始转录")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(viewModel.canTranscribe ? Color(hex: "007AFF") : Color(hex: "007AFF").opacity(0.5))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .disabled(!viewModel.canTranscribe)
    }

    // MARK: - 任务列表区域
    private var tasksSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("转录任务")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color(hex: "1D1D1F"))

                Spacer()

                Menu {
                    Button("清理已完成任务", role: .destructive) {
                        taskManager.tasks.removeAll { $0.status == .completed || $0.status == .failed }
                        taskManager.saveTasks()
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 18))
                        .foregroundColor(Color(hex: "6E6E73"))
                }
            }

            ForEach(taskManager.tasks) { task in
                TaskCardView(
                    task: task,
                    onImport: {
                        viewModel.importTask(task)
                        showToastMessage("已导入到视频库", style: .success)
                    },
                    onDelete: {
                        taskManager.deleteTask(task.id)
                        showToastMessage("任务已删除", style: .info)
                    },
                    onCancel: {
                        taskManager.cancelTask(task.id)
                    },
                    onDetail: {
                        showingTaskDetail = task
                    }
                )
            }
        }
    }

    private var subtitleFooterText: String {
        switch viewModel.subtitleMode {
        case .original:
            return "选择 MP4 或 MOV 格式的视频，语音将被转录为字幕"
        case .chinese:
            return "转录并翻译为中文，只显示中文字幕"
        case .bilingual:
            return "转录原语言并翻译为中文，同时显示原文和中文"
        }
    }

    private func showToastMessage(_ message: String, style: ToastView.ToastStyle) {
        toastMessage = message
        toastStyle = style
        withAnimation {
            showToast = true
        }
    }
}

// MARK: - 任务卡片视图
private struct TaskCardView: View {
    let task: TranscriptionTask
    let onImport: () -> Void
    let onDelete: () -> Void
    let onCancel: () -> Void
    let onDetail: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            // 状态图标
            statusIcon
                .frame(width: 44, height: 44)
                .background(statusIconBackground)
                .cornerRadius(12)

            // 任务信息
            VStack(alignment: .leading, spacing: 6) {
                Text(task.videoTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color(hex: "1D1D1F"))
                    .lineLimit(1)

                Text(statusText)
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "8E8E93"))
            }

            Spacer()

            // 右侧操作
            rightAction
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(16)
        .contextMenu {
            if task.status == .completed {
                Button {
                    onImport()
                } label: {
                    Label("导入到视频库", systemImage: "square.and.arrow.down")
                }
            }

            Button {
                onDetail()
            } label: {
                Label("查看详情", systemImage: "info.circle")
            }

            Divider()

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
        .onTapGesture {
            if task.status == .completed || task.status == .failed {
                onDetail()
            }
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch task.status {
        case .inProgress:
            Image(systemName: "film")
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

    private var statusText: String {
        switch task.status {
        case .queued:
            return "排队中"
        case .inProgress:
            return "转录中... \(Int(task.progress * 100))%"
        case .completed:
            return "已完成 · \(task.subtitleMode.displayName)"
        case .failed:
            return "失败: \(task.errorMessage ?? "未知错误")"
        case .cancelled:
            return "已取消"
        }
    }

    @ViewBuilder
    private var rightAction: some View {
        switch task.status {
        case .inProgress:
            // 进度条
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(hex: "E5E5EA"))
                    .frame(width: 80, height: 4)

                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(hex: "007AFF"))
                    .frame(width: max(4, 80 * CGFloat(task.progress)), height: 4)
            }
            .frame(width: 80)

        case .completed:
            Button(action: onImport) {
                Text("导入")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(hex: "007AFF"))
                    .frame(width: 60, height: 32)
                    .background(Color(hex: "F5F5F7"))
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)

        case .failed, .queued, .cancelled:
            EmptyView()
        }
    }
}

#Preview {
    TranscriptionView()
}
