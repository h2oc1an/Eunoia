import Foundation

// MARK: - Download Session Delegate
/// URLSession delegate，用于接收后台下载进度和完成回调
/// 必须是 NSObject 类（不能是 actor），因为 URLSession 在串行队列上调用 delegate
final class DownloadSessionDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private let taskId: UUID
    private let progressHandler: (Double, Int64) -> Void
    private let completionHandler: (Result<URL, Error>) -> Void
    private let temporaryDirectory: URL
    private let finalDirectory: URL

    init(
        taskId: UUID,
        temporaryDirectory: URL,
        finalDirectory: URL,
        progress: @escaping (Double, Int64) -> Void,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        self.taskId = taskId
        self.temporaryDirectory = temporaryDirectory
        self.finalDirectory = finalDirectory
        self.progressHandler = progress
        self.completionHandler = completion
        super.init()
    }

    // MARK: - Download Progress
    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        let progress: Double
        if totalBytesExpectedToWrite > 0 {
            progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        } else {
            progress = 0
        }
        progressHandler(progress, totalBytesWritten)
    }

    // MARK: - Download Complete
    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        do {
            // 将文件从临时位置移动到目标目录
            try FileManager.default.createDirectory(at: finalDirectory, withIntermediateDirectories: true)

            let suggestedFilename = downloadTask.response?.suggestedFilename
                ?? location.lastPathComponent
            let rawExt = (suggestedFilename as NSString).pathExtension
            // .m4s 等 DASH 分段格式统一用 .mp4，确保 AVFoundation 兼容
            let fileExt: String = {
                let videoExtensions = ["mp4", "mov", "mkv", "m4v", "avi", "webm", "flv"]
                let mappedExtensions = ["m4s": "mp4", "ts": "mp4"]
                if videoExtensions.contains(rawExt.lowercased()) { return rawExt }
                if let mapped = mappedExtensions[rawExt.lowercased()] { return mapped }
                return rawExt.isEmpty ? "mp4" : rawExt
            }()
            let destinationURL = finalDirectory
                .appendingPathComponent(taskId.uuidString)
                .appendingPathExtension(fileExt)

            // 创建父目录
            try FileManager.default.createDirectory(
                at: destinationURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            // 移动文件（如果已存在则覆盖）
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.moveItem(at: location, to: destinationURL)

            completionHandler(.success(destinationURL))
        } catch {
            completionHandler(.failure(DownloadServiceError.fileMoveFailed(error)))
        }
    }

    // MARK: - Download Error / Complete with Error
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            let nsError = error as NSError
            // 如果用户取消了下载，不要当作错误处理
            if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                return
            }
            completionHandler(.failure(DownloadServiceError.downloadFailed(error)))
        }
    }

    // MARK: - Background Completion
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        print("[DownloadSessionDelegate] 后台 URLSession 事件处理完毕: \(taskId)")
    }
}

// MARK: - Download Service Errors
enum DownloadServiceError: LocalizedError {
    case invalidURL
    case noExtractorFound(URL)
    case allExtractorsFailed(Error?)
    case downloadFailed(Error)
    case fileMoveFailed(Error)
    case taskNotFound

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "无效的 URL"
        case .noExtractorFound(let url): return "未找到支持该链接的提取器: \(url.host ?? url.absoluteString)"
        case .allExtractorsFailed(let error): return "解析失败: \(error?.localizedDescription ?? "未知错误")"
        case .downloadFailed(let error): return "下载失败: \(error.localizedDescription)"
        case .fileMoveFailed(let error): return "文件移动失败: \(error.localizedDescription)"
        case .taskNotFound: return "下载任务未找到"
        }
    }
}

// MARK: - Download Service
/// HTTP 下载服务，协调 URL 解析和文件下载
actor DownloadService {
    static let shared = DownloadService()

    // 提取器链（按优先级排列）
    private let extractors: [any VideoExtractor] = [
        DirectURLExtractor(),
        YouTubeExtractor(),
        BilibiliExtractor(),
        CobaltExtractor()
    ]

    // 活跃的 URLSession，按任务 ID 索引
    private var activeSessions: [UUID: URLSession] = [:]
    private var activeTasks: [UUID: URLSessionDownloadTask] = [:]
    private var delegates: [UUID: DownloadSessionDelegate] = [:]

    // 下载目录
    private let downloadDirectory: URL
    private let partialDirectory: URL

    private init() {
        downloadDirectory = Platform.videosURL
        partialDirectory = Platform.downloadsURL.appendingPathComponent("Partial", isDirectory: true)

        try? FileManager.default.createDirectory(at: downloadDirectory, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: partialDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Parse URL
    /// 解析视频 URL，返回提取结果
    func parseURL(_ urlString: String) async throws -> ExtractionResult {
        guard let url = URL(string: urlString) else {
            throw DownloadServiceError.invalidURL
        }

        // 标准化 URL：没有 scheme 或 host 为空都说明 URL 解析不完整（例如用户省略了 https://）
        var normalizedURL = url
        if url.scheme == nil || url.host == nil || !(url.scheme?.hasPrefix("http") ?? false) {
            let cleaned = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
            let prefixed = cleaned.hasPrefix("http://") || cleaned.hasPrefix("https://")
                ? cleaned : "https://\(cleaned)"
            if let httpsURL = URL(string: prefixed) {
                normalizedURL = httpsURL
            } else {
                throw DownloadServiceError.invalidURL
            }
        }

        // 遍历提取器链，收集错误信息
        var triedExtractors: [String] = []
        var lastError: Error?

        for extractor in extractors {
            let extractorName = String(describing: type(of: extractor))
            if type(of: extractor).canHandle(normalizedURL) {
                triedExtractors.append(extractorName)
                do {
                    let result = try await extractor.extract(from: normalizedURL)
                    return result
                } catch {
                    lastError = error
                    print("[DownloadService] \(extractorName) 提取失败: \(error)")
                    continue
                }
            }
        }

        if triedExtractors.isEmpty {
            throw DownloadServiceError.noExtractorFound(normalizedURL)
        } else {
            throw DownloadServiceError.allExtractorsFailed(lastError)
        }
    }

    // MARK: - Start Download
    /// 开始下载文件到目标路径
    func startDownload(
        taskId: UUID,
        from url: URL,
        referer: String? = nil,
        progress: @escaping (Double, Int64) -> Void,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        // 使用后台配置以支持后台下载
        let config = URLSessionConfiguration.background(
            withIdentifier: "com.eunoia.download.\(taskId.uuidString)"
        )
        config.sessionSendsLaunchEvents = true
        config.isDiscretionary = false
        config.timeoutIntervalForRequest = 300

        let delegate = DownloadSessionDelegate(
            taskId: taskId,
            temporaryDirectory: partialDirectory,
            finalDirectory: downloadDirectory,
            progress: progress,
            completion: completion
        )
        delegates[taskId] = delegate

        let session = URLSession(
            configuration: config,
            delegate: delegate,
            delegateQueue: nil
        )
        activeSessions[taskId] = session

        var request = URLRequest(url: url)
        request.timeoutInterval = 300
        // 模拟浏览器 User-Agent（Bilibili CDN 校验）
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        if let referer = referer {
            request.setValue(referer, forHTTPHeaderField: "Referer")
        }
        // Bilibili CDN 防盗链：Referer + Origin 都需要
        if referer == "https://www.bilibili.com" {
            request.setValue("https://www.bilibili.com", forHTTPHeaderField: "Origin")
        }

        let downloadTask = session.downloadTask(with: request)
        downloadTask.countOfBytesClientExpectsToSend = 0
        downloadTask.countOfBytesClientExpectsToReceive = Int64(1_000_000_000)
        downloadTask.resume()

        activeTasks[taskId] = downloadTask
    }

    // MARK: - Pause Download
    func pauseDownload(taskId: UUID) {
        guard let task = activeTasks[taskId] else { return }
        task.cancel { resumeData in
            // 保存 resume data 以支持断点续传
            if let data = resumeData {
                let resumeURL = self.partialDirectory
                    .appendingPathComponent("\(taskId.uuidString).resume")
                try? data.write(to: resumeURL)
                print("[DownloadService] 已保存 resume data: \(data.count) bytes")
            }
        }
        activeTasks.removeValue(forKey: taskId)
    }

    // MARK: - Resume Download
    func resumeDownload(
        taskId: UUID,
        from url: URL,
        progress: @escaping (Double, Int64) -> Void,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        let resumeURL = partialDirectory
            .appendingPathComponent("\(taskId.uuidString).resume")

        let config = URLSessionConfiguration.background(
            withIdentifier: "com.eunoia.download.\(taskId.uuidString)"
        )
        config.sessionSendsLaunchEvents = true
        config.isDiscretionary = false

        let delegate = DownloadSessionDelegate(
            taskId: taskId,
            temporaryDirectory: partialDirectory,
            finalDirectory: downloadDirectory,
            progress: progress,
            completion: completion
        )
        delegates[taskId] = delegate

        let session = URLSession(
            configuration: config,
            delegate: delegate,
            delegateQueue: nil
        )
        activeSessions[taskId] = session

        let downloadTask: URLSessionDownloadTask
        if let resumeData = try? Data(contentsOf: resumeURL) {
            // 使用 resume data 续传
            downloadTask = session.downloadTask(withResumeData: resumeData)
            try? FileManager.default.removeItem(at: resumeURL)
        } else {
            // 从头下载
            downloadTask = session.downloadTask(with: url)
        }
        downloadTask.resume()

        activeTasks[taskId] = downloadTask
    }

    // MARK: - Cancel Download
    func cancelDownload(taskId: UUID) {
        activeTasks[taskId]?.cancel()
        activeTasks.removeValue(forKey: taskId)
        activeSessions[taskId]?.invalidateAndCancel()
        activeSessions.removeValue(forKey: taskId)
        delegates.removeValue(forKey: taskId)

        // 清理 resume data
        let resumeURL = partialDirectory
            .appendingPathComponent("\(taskId.uuidString).resume")
        try? FileManager.default.removeItem(at: resumeURL)
    }

    // MARK: - File Paths
    func getDownloadPath(for taskId: UUID) -> URL {
        return downloadDirectory.appendingPathComponent("\(taskId.uuidString).mp4")
    }

    func getPartialPath(for taskId: UUID) -> URL {
        return partialDirectory.appendingPathComponent("\(taskId.uuidString).part")
    }

    // MARK: - Cleanup
    func cleanupDownload(taskId: UUID) {
        let partialFile = partialDirectory.appendingPathComponent("\(taskId.uuidString).part")
        try? FileManager.default.removeItem(at: partialFile)

        let resumeFile = partialDirectory.appendingPathComponent("\(taskId.uuidString).resume")
        try? FileManager.default.removeItem(at: resumeFile)
    }
}
