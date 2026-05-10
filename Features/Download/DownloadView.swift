import SwiftUI

struct DownloadView: View {
    @StateObject private var viewModel = DownloadViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showFormatSheet = false
    @State private var showTranscribePicker = false
    @State private var pendingTranscribeTask: DownloadTask?

    var body: some View {
        NavigationStack {
            List {
                // URL 输入区
                Section {
                    TextField("视频链接 (URL)", text: $viewModel.inputURL)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()

                    TextField("标题（可选，用于显示）", text: $viewModel.videoTitle)

                    Button(action: {
                        Task { await viewModel.parseURL() }
                    }) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.blue)
                            Text("解析并下载")
                            Spacer()
                            if viewModel.isParsing {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(!viewModel.canStartDownload || viewModel.isParsing)
                } header: {
                    Text("视频链接")
                } footer: {
                    Text("支持直接视频链接（mp4、mkv 等）、YouTube、Bilibili 等平台链接")
                }

                // 解析结果预览
                if let result = viewModel.extractionResult {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(result.platform.uppercased())
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(platformColor(result.platform))
                                    .cornerRadius(4)

                                if let duration = result.duration {
                                    let minutes = Int(duration) / 60
                                    let seconds = Int(duration) % 60
                                    Text(String(format: "%d:%02d", minutes, seconds))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }

                            Text(result.title)
                                .font(.headline)
                                .lineLimit(2)

                            if let uploader = result.uploader {
                                Text("up: \(uploader)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            if !result.formats.isEmpty {
                                Text("\(result.formats.count) 个可用格式")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }

                            if viewModel.hasFormats {
                                Button("选择画质") {
                                    showFormatSheet = true
                                }
                                .font(.caption)
                                .buttonStyle(.bordered)
                            }
                        }
                    } header: {
                        Text("视频信息")
                    }

                }

                // Error Display
                if let error = viewModel.errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }

                // Success Message
                if let success = viewModel.successMessage {
                    Section {
                        Text(success)
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                }

                // Active Downloads
                if !viewModel.activeTasks.isEmpty {
                    Section {
                        ForEach(viewModel.activeTasks) { task in
                            DownloadTaskRow(
                                task: task,
                                onPause: { Task { await viewModel.pauseDownload(task) } },
                                onResume: { Task { await viewModel.resumeDownload(task) } },
                                onCancel: { Task { await viewModel.cancelDownload(task) } }
                            )
                        }
                    } header: {
                        Text("正在下载")
                    }
                }

                // Completed Downloads
                if !viewModel.completedTasks.isEmpty {
                    Section {
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
                    } header: {
                        Text("已完成")
                    }
                }

                // 免责声明
                Section {
                    Text("请遵守版权法规，仅下载您有权下载的内容。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("下载视频")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { dismiss() }
                }
            }
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
    }

    private func platformColor(_ platform: String) -> Color {
        switch platform.lowercased() {
        case "youtube": return .red
        case "bilibili": return .pink
        case "direct": return .green
        default: return .gray
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
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title)
                        .font(.headline)
                        .lineLimit(1)

                    Text(task.sourceLabel)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                statusBadge
            }

            ProgressView(value: task.progress)
                .tint(progressColor)

            HStack {
                Text("\(task.displayProgress) - \(task.downloadedSizeFormatted) / \(task.totalSizeFormatted)")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Spacer()

                HStack(spacing: 12) {
                    if task.status == .downloading {
                        Button(action: onPause) {
                            Image(systemName: "pause.circle")
                                .foregroundColor(.orange)
                        }
                    } else if task.status == .paused {
                        Button(action: onResume) {
                            Image(systemName: "play.circle")
                                .foregroundColor(.green)
                        }
                    }

                    Button(action: onCancel) {
                        Image(systemName: "xmark.circle")
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    var statusBadge: some View {
        switch task.status {
        case .pending:
            Text("等待中")
                .badgeStyle(backgroundColor: Color.gray.opacity(0.3))
        case .parsing:
            Text("解析中")
                .badgeStyle(backgroundColor: Color.purple.opacity(0.3))
        case .downloading:
            Text("下载中")
                .badgeStyle(backgroundColor: Color.blue.opacity(0.3))
        case .paused:
            Text("已暂停")
                .badgeStyle(backgroundColor: Color.orange.opacity(0.3))
        case .failed:
            Text("失败")
                .badgeStyle(backgroundColor: Color.red.opacity(0.3))
        case .cancelled:
            Text("已取消")
                .badgeStyle(backgroundColor: Color.gray.opacity(0.3))
        case .completed:
            Text("已完成")
                .badgeStyle(backgroundColor: Color.green.opacity(0.3))
        }
    }

    var progressColor: Color {
        switch task.status {
        case .downloading: return .blue
        case .paused: return .orange
        case .completed: return .green
        case .failed, .cancelled: return .red
        default: return .gray
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
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(task.title)
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                Text(task.totalSizeFormatted)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 12) {
                Button(action: onImport) {
                    Label("导入", systemImage: "plus.circle")
                        .font(.caption)
                }
                .buttonStyle(.bordered)

                Button(action: onTranscribe) {
                    Label("转录", systemImage: "captions.bubble")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .tint(.purple)

                Button(action: onDelete) {
                    Label("删除", systemImage: "trash")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Badge Style Modifier
extension Text {
    func badgeStyle(backgroundColor: Color) -> some View {
        self.font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(backgroundColor)
            .cornerRadius(4)
    }
}

#Preview {
    DownloadView()
}
