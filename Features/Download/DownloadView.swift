import SwiftUI

struct DownloadView: View {
    @StateObject private var viewModel = DownloadViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showFormatSheet = false
    @State private var showTranscribePicker = false
    @State private var pendingTranscribeTask: DownloadTask?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 标题栏
                HStack {
                    Text("下载视频")
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

                // 链接卡片
                linkCard

                // 解析结果
                if let result = viewModel.extractionResult {
                    resultCard(result)
                }

                // 错误/成功消息
                if let error = viewModel.errorMessage {
                    messageCard(error, color: "FF3B30")
                }
                if let success = viewModel.successMessage {
                    messageCard(success, color: "34C759")
                }

                // 正在下载
                if !viewModel.activeTasks.isEmpty {
                    activeTasksCard
                }

                // 已完成
                if !viewModel.completedTasks.isEmpty {
                    completedTasksCard
                }

                // 免责声明
                Text("请遵守版权法规，仅下载您有权下载的内容。")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "8E8E93"))

                // 完成按钮
                Button(action: { dismiss() }) {
                    Text("完成")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(Color(hex: "007AFF"))
                        .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }
            .padding(32)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(hex: "F5F5F7"))
        .sheet(isPresented: $showFormatSheet) {
            if let result = viewModel.extractionResult {
                FormatPickerView(
                    formats: result.formats,
                    selectedFormat: $viewModel.selectedFormat,
                    onConfirm: {
                        showFormatSheet = false
                        Task { await viewModel.startDownload() }
                    }
                )
            }
        }
        .sheet(isPresented: $showTranscribePicker) {
            SubtitleModePickerView { mode in
                if let task = pendingTranscribeTask {
                    viewModel.transcribeCompletedTask(task, mode: mode)
                }
            }
        }
        .alert("下载完成", isPresented: $viewModel.showDownloadComplete) {
            Button("好的", role: .cancel) {}
        } message: {
            if let video = viewModel.newlyDownloadedVideo {
                Text("\(video.title) 已添加到视频库。")
            }
        }
        .alert("转录任务", isPresented: $viewModel.showTranscribeAlert) {
            Button("好的", role: .cancel) {}
        } message: {
            Text(viewModel.transcribeAlertMessage)
        }
    }

    // MARK: - 链接卡片
    private var linkCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("视频链接")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color(hex: "1D1D1F"))

            ZStack(alignment: .topLeading) {
                TextEditor(text: $viewModel.inputURL)
                    .font(.system(size: 15))
                    .autocorrectionDisabled()
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .frame(minHeight: 60)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)

                if viewModel.inputURL.isEmpty {
                    Text("视频链接 (URL)")
                        .font(.system(size: 15))
                        .foregroundColor(Color(hex: "C7C7CC"))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .allowsHitTesting(false)
                }
            }
            .background(Color(hex: "F5F5F7"))
            .cornerRadius(10)

            TextField("标题（可选，用于显示）", text: $viewModel.videoTitle)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .padding(12)
                .background(Color(hex: "F5F5F7"))
                .cornerRadius(10)

            Button(action: {
                Task { await viewModel.parseURL() }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14))
                    Text("解析并下载")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(viewModel.canStartDownload && !viewModel.isParsing ? Color(hex: "007AFF") : Color(hex: "007AFF").opacity(0.5))
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.canStartDownload || viewModel.isParsing)

            Text("支持直接视频链接（mp4、mkv 等）、YouTube、Bilibili 等平台链接")
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "8E8E93"))
        }
        .padding(24)
        .background(Color.white)
        .cornerRadius(16)
    }

    // MARK: - 解析结果卡片
    private func resultCard(_ result: ExtractionResult) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("视频信息")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color(hex: "1D1D1F"))

            HStack(spacing: 8) {
                Text(result.platform.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(platformColor(result.platform))
                    .cornerRadius(4)

                if let duration = result.duration {
                    let minutes = Int(duration) / 60
                    let seconds = Int(duration) % 60
                    Text(String(format: "%d:%02d", minutes, seconds))
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "8E8E93"))
                }

                Spacer()
            }

            Text(result.title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color(hex: "1D1D1F"))
                .lineLimit(2)

            if let uploader = result.uploader {
                Text("up: \(uploader)")
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "8E8E93"))
            }

            if !result.formats.isEmpty {
                Text("\(result.formats.count) 个可用格式")
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "007AFF"))
            }

            if viewModel.hasFormats {
                Button(action: { showFormatSheet = true }) {
                    Text("选择画质")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: "007AFF"))
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background(Color(hex: "F5F5F7"))
                        .cornerRadius(10)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(24)
        .background(Color.white)
        .cornerRadius(16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 正在下载卡片
    private var activeTasksCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("正在下载")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color(hex: "1D1D1F"))

            VStack(spacing: 12) {
                ForEach(viewModel.activeTasks) { task in
                    DownloadTaskRow(
                        task: task,
                        onPause: { Task { await viewModel.pauseDownload(task) } },
                        onResume: { Task { await viewModel.resumeDownload(task) } },
                        onCancel: { Task { await viewModel.cancelDownload(task) } }
                    )
                }
            }
        }
        .padding(24)
        .background(Color.white)
        .cornerRadius(16)
    }

    // MARK: - 已完成卡片
    private var completedTasksCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("已完成")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color(hex: "1D1D1F"))

            VStack(spacing: 12) {
                ForEach(viewModel.completedTasks) { task in
                    CompletedDownloadRow(
                        task: task,
                        onImport: { Task { await viewModel.importToVideoLibrary(task) } },
                        onTranscribe: {
                            pendingTranscribeTask = task
                            showTranscribePicker = true
                        },
                        onDelete: { Task { await viewModel.deleteTask(task) } }
                    )
                }
            }
        }
        .padding(24)
        .background(Color.white)
        .cornerRadius(16)
    }

    private func messageCard(_ message: String, color: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: color == "FF3B30" ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .font(.system(size: 16))
                .foregroundColor(Color(hex: color))

            Text(message)
                .font(.system(size: 14))
                .foregroundColor(Color(hex: color))

            Spacer()
        }
        .padding(16)
        .background(Color(hex: color).opacity(0.08))
        .cornerRadius(12)
    }

    private func platformColor(_ platform: String) -> Color {
        switch platform.lowercased() {
        case "youtube": return Color(hex: "FF3B30")
        case "bilibili": return Color(hex: "FF9500")
        case "direct": return Color(hex: "34C759")
        default: return Color(hex: "8E8E93")
        }
    }
}

// MARK: - Download Task Row
struct DownloadTaskRow: View {
    let task: DownloadTask
    let onPause: () -> Void
    let onResume: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color(hex: "1D1D1F"))
                        .lineLimit(1)

                    Text(task.sourceLabel)
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "8E8E93"))
                }

                Spacer()

                statusBadge
            }

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(hex: "E5E5EA"))
                    .frame(height: 4)

                RoundedRectangle(cornerRadius: 2)
                    .fill(progressColor)
                    .frame(width: max(4, 200 * CGFloat(task.progress)), height: 4)
            }
            .frame(maxWidth: 200)

            HStack {
                Text("\(task.displayProgress) · \(task.downloadedSizeFormatted) / \(task.totalSizeFormatted)")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "8E8E93"))

                Spacer()

                HStack(spacing: 16) {
                    if task.status == .downloading {
                        Button(action: onPause) {
                            Image(systemName: "pause.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(Color(hex: "FF9500"))
                        }
                        .buttonStyle(.plain)
                    } else if task.status == .paused {
                        Button(action: onResume) {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(Color(hex: "34C759"))
                        }
                        .buttonStyle(.plain)
                    }

                    Button(action: onCancel) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Color(hex: "FF3B30"))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(Color(hex: "F5F5F7"))
        .cornerRadius(12)
    }

    @ViewBuilder
    var statusBadge: some View {
        switch task.status {
        case .pending:
            badgeText("等待中", color: "8E8E93")
        case .parsing:
            badgeText("解析中", color: "5856D6")
        case .downloading:
            badgeText("下载中", color: "007AFF")
        case .paused:
            badgeText("已暂停", color: "FF9500")
        case .failed:
            badgeText("失败", color: "FF3B30")
        case .cancelled:
            badgeText("已取消", color: "8E8E93")
        case .completed:
            badgeText("已完成", color: "34C759")
        }
    }

    private func badgeText(_ text: String, color: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(Color(hex: color))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color(hex: color).opacity(0.1))
            .cornerRadius(4)
    }

    var progressColor: Color {
        switch task.status {
        case .downloading: return Color(hex: "007AFF")
        case .paused: return Color(hex: "FF9500")
        case .completed: return Color(hex: "34C759")
        case .failed, .cancelled: return Color(hex: "FF3B30")
        default: return Color(hex: "8E8E93")
        }
    }
}

// MARK: - Completed Download Row
struct CompletedDownloadRow: View {
    let task: DownloadTask
    let onImport: () -> Void
    let onTranscribe: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(task.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color(hex: "1D1D1F"))
                    .lineLimit(1)

                Text(task.totalSizeFormatted)
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "8E8E93"))
            }

            Spacer()

            HStack(spacing: 8) {
                Button(action: onImport) {
                    Text("导入")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(hex: "007AFF"))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(hex: "F5F5F7"))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)

                Button(action: onTranscribe) {
                    Text("转录")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(hex: "5856D6"))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(hex: "F5F5F7"))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "FF3B30"))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(hex: "F5F5F7"))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(Color(hex: "F5F5F7"))
        .cornerRadius(12)
    }
}

#Preview {
    DownloadView()
}
