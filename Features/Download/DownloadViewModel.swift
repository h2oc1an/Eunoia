import Foundation
import Combine

@MainActor
class DownloadViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var inputURL: String = ""
    @Published var videoTitle: String = ""
    @Published var isLoading: Bool = false
    @Published var isParsing: Bool = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var activeTasks: [DownloadTask] = []
    @Published var completedTasks: [DownloadTask] = []
    @Published var showFormatPicker: Bool = false
    @Published var showDownloadComplete: Bool = false
    @Published var newlyDownloadedVideo: Video?
    @Published var showTranscribeAlert: Bool = false
    @Published var transcribeAlertMessage: String = ""

    // 解析结果（用于格式选择）
    @Published var extractionResult: ExtractionResult?
    @Published var selectedFormat: VideoFormat?

    // MARK: - Private Properties
    private let downloadService = DownloadService.shared
    private let repository = DownloadTaskRepository()
    private let videoRepository = VideoRepository()
    private let thumbnailService = ThumbnailService.shared

    // MARK: - Computed Properties
    var canStartDownload: Bool {
        !inputURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoading
    }

    var hasFormats: Bool {
        extractionResult?.formats.isEmpty == false
    }

    // MARK: - Lifecycle
    init() {
        loadTasks()
    }

    // MARK: - Load Tasks
    func loadTasks() {
        do {
            let allTasks = try repository.getAll()
            activeTasks = allTasks.filter { $0.isActive }
            completedTasks = allTasks.filter { $0.status == .completed }
        } catch {
            print("[DownloadViewModel] 加载任务失败: \(error)")
        }
    }

    // MARK: - Parse URL
    /// 解析输入的视频 URL
    func parseURL() async {
        let urlString = inputURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !urlString.isEmpty else {
            errorMessage = "请输入视频链接"
            return
        }

        isParsing = true
        errorMessage = nil

        do {
            let result = try await downloadService.parseURL(urlString)
            extractionResult = result

            if result.formats.count > 1 {
                // 多个格式可选，显示格式选择
                showFormatPicker = true
                // 默认选中最佳格式（有音频 + 最高分辨率）
                selectedFormat = result.formats.first { $0.hasAudio && $0.height > 0 }
                    ?? result.formats.first
            } else {
                // 只有一个格式或直链，直接开始下载
                if let format = result.formats.first {
                    selectedFormat = format
                }
                await startDownload()
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isParsing = false
    }

    // MARK: - Start Download
    func startDownload() async {
        guard let result = extractionResult else {
            errorMessage = "请先解析视频链接"
            return
        }

        isLoading = true
        errorMessage = nil
        showFormatPicker = false

        // 确定下载 URL
        let downloadURL: URL
        if let directURL = result.directURL {
            downloadURL = directURL
        } else if let format = selectedFormat, let formatURL = URL(string: format.id) {
            downloadURL = formatURL
        } else {
            errorMessage = "无法获取下载链接"
            isLoading = false
            return
        }

        // 确定标题
        let title: String
        if !videoTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            title = videoTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            title = result.title
        }

        // 判断来源类型
        let sourceType: DownloadSourceType = result.platform == "direct" ? .directURL : .platformURL

        // 构建元数据
        let metadata = VideoMetadata(
            platformId: result.title,
            title: result.title,
            thumbnailURL: result.thumbnailURL?.absoluteString,
            duration: result.duration,
            platform: result.platform,
            uploader: result.uploader,
            formats: result.formats,
            directURL: result.directURL?.absoluteString,
            fileSize: selectedFormat?.fileSize ?? result.fileSize
        )

        // 创建任务
        let task = DownloadTask(
            sourceType: sourceType,
            sourceURL: inputURL.trimmingCharacters(in: .whitespacesAndNewlines),
            title: title,
            totalBytes: selectedFormat?.fileSize ?? result.fileSize,
            metadata: metadata,
            selectedFormat: selectedFormat
        )

        // 保存到数据库
        do {
            try repository.save(task)
        } catch {
            errorMessage = "保存任务失败: \(error.localizedDescription)"
        }
        loadTasks()

        // 开始下载
        do {
            try repository.updateStatus(task.id, status: .downloading, progress: 0, downloadedBytes: 0)
        } catch {
            print("[DownloadViewModel] 更新状态失败: \(error)")
        }

        // 根据平台设置 Referer（Bilibili CDN 需要防盗链 header）
        let referer: String? = {
            switch result.platform {
            case "bilibili": return "https://www.bilibili.com"
            case "youtube": return "https://www.youtube.com"
            default: return nil
            }
        }()

        await downloadService.startDownload(
            taskId: task.id,
            from: downloadURL,
            referer: referer,
            progress: { [weak self] progress, downloadedBytes in
                Task { @MainActor in
                    do {
                        try self?.repository.updateStatus(
                            task.id, status: .downloading,
                            progress: progress,
                            downloadedBytes: downloadedBytes
                        )
                        self?.loadTasks()
                    } catch {
                        print("[DownloadViewModel] 更新进度失败: \(error)")
                    }
                }
            },
            completion: { [weak self] result in
                Task { @MainActor in
                    switch result {
                    case .success(let url):
                        do {
                            try self?.repository.updateCompleted(task.id, localPath: url.path)
                            self?.successMessage = "下载完成: \(url.lastPathComponent)"
                        } catch {
                            self?.errorMessage = "保存完成状态失败: \(error.localizedDescription)"
                        }
                    case .failure(let error):
                        do {
                            try self?.repository.updateFailed(task.id, error: error.localizedDescription)
                            self?.errorMessage = "下载失败: \(error.localizedDescription)"
                        } catch {
                            print("[DownloadViewModel] 保存失败状态错误: \(error)")
                        }
                    }
                    self?.isLoading = false
                    self?.loadTasks()
                }
            }
        )

        // 清空输入
        inputURL = ""
        videoTitle = ""
        extractionResult = nil
        selectedFormat = nil
        isLoading = false
        loadTasks()
    }

    // MARK: - Pause Download
    func pauseDownload(_ task: DownloadTask) async {
        await downloadService.pauseDownload(taskId: task.id)
        do {
            try repository.updateStatus(task.id, status: .paused)
            loadTasks()
        } catch {
            errorMessage = "暂停失败: \(error.localizedDescription)"
        }
    }

    // MARK: - Resume Download
    func resumeDownload(_ task: DownloadTask) async {
        guard let downloadURL = getTaskDownloadURL(task) else {
            errorMessage = "无法恢复下载: 缺少下载链接"
            return
        }

        await downloadService.resumeDownload(
            taskId: task.id,
            from: downloadURL,
            progress: { [weak self] progress, downloadedBytes in
                Task { @MainActor in
                    do {
                        try self?.repository.updateStatus(
                            task.id, status: .downloading,
                            progress: progress,
                            downloadedBytes: downloadedBytes
                        )
                        self?.loadTasks()
                    } catch {
                        print("[DownloadViewModel] 恢复进度更新失败: \(error)")
                    }
                }
            },
            completion: { [weak self] result in
                Task { @MainActor in
                    switch result {
                    case .success(let url):
                        do {
                            try self?.repository.updateCompleted(task.id, localPath: url.path)
                            self?.successMessage = "下载完成: \(url.lastPathComponent)"
                        } catch {
                            self?.errorMessage = "保存完成状态失败: \(error.localizedDescription)"
                        }
                    case .failure(let error):
                        do {
                            try self?.repository.updateFailed(task.id, error: error.localizedDescription)
                            self?.errorMessage = "恢复下载失败: \(error.localizedDescription)"
                        } catch {
                            print("[DownloadViewModel] 保存错误: \(error)")
                        }
                    }
                    self?.isLoading = false
                    self?.loadTasks()
                }
            }
        )

        do {
            try repository.updateStatus(task.id, status: .downloading)
            loadTasks()
        } catch {
            errorMessage = "恢复失败: \(error.localizedDescription)"
        }
    }

    // MARK: - Cancel Download
    func cancelDownload(_ task: DownloadTask) async {
        await downloadService.cancelDownload(taskId: task.id)
        do {
            try repository.updateStatus(task.id, status: .cancelled)
            loadTasks()
        } catch {
            errorMessage = "取消失败: \(error.localizedDescription)"
        }
    }

    // MARK: - Delete Task
    func deleteTask(_ task: DownloadTask) async {
        await downloadService.cleanupDownload(taskId: task.id)

        if let localPath = task.localPath {
            try? FileManager.default.removeItem(atPath: localPath)
        }

        do {
            try repository.delete(task.id)
            loadTasks()
        } catch {
            errorMessage = "删除失败: \(error.localizedDescription)"
        }
    }

    // MARK: - Import to Video Library
    func importToVideoLibrary(_ task: DownloadTask) async {
        guard let localPath = task.localPath else {
            errorMessage = "未找到下载文件"
            return
        }

        do {
            // 生成缩略图
            let thumbDir = FileManager.default.temporaryDirectory
            let thumbnailPath = await MainActor.run {
                thumbnailService.generateThumbnailSync(for: localPath, saveToDirectory: thumbDir)
            }

            // 获取视频时长
            let asset = AVAsset(url: URL(fileURLWithPath: localPath))
            let duration: Double
            if #available(iOS 16.0, *) {
                duration = try await asset.load(.duration).seconds
            } else {
                duration = CMTimeGetSeconds(asset.duration)
            }

            // 创建视频记录
            let video = Video(
                title: task.title,
                localPath: localPath,
                thumbnailPath: thumbnailPath,
                duration: duration,
                downloadTaskId: task.id,
                sourceURL: task.sourceURL,
                fileSize: task.totalBytes
            )

            try videoRepository.save(video)
            try repository.updateCompleted(task.id, localPath: localPath)
            loadTasks()

            newlyDownloadedVideo = video
            showDownloadComplete = true

        } catch {
            errorMessage = "导入视频库失败: \(error.localizedDescription)"
        }
    }

    // MARK: - Transcription for Completed Task
    /// 为已完成的下载任务启动转录（后台执行，不阻塞 UI）
    func transcribeCompletedTask(_ task: DownloadTask, mode: SubtitleMode) {
        guard let localPath = task.localPath else { return }

        TranscriptionTaskManager.shared.startTranscription(
            videoTitle: task.title,
            videoPath: localPath,
            subtitleMode: mode
        )
        transcribeAlertMessage = "已创建转录任务，可前往「转录」页面查看进度"
        showTranscribeAlert = true
    }

    // MARK: - Helpers
    private func getTaskDownloadURL(_ task: DownloadTask) -> URL? {
        if let directURL = task.metadata?.directURL, let url = URL(string: directURL) {
            return url
        }
        if let formatURL = task.selectedFormat?.id, let url = URL(string: formatURL) {
            return url
        }
        if let sourceURL = URL(string: task.sourceURL) {
            return sourceURL
        }
        return nil
    }
}

import AVFoundation
