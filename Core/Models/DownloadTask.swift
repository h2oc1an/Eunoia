import Foundation

// MARK: - Download Source Type
enum DownloadSourceType: String, Codable {
    case directURL     // 直接视频链接（如 .mp4）
    case platformURL   // 平台链接（YouTube、Bilibili 等，需提取器解析）
}

// MARK: - Download Status
enum DownloadStatus: String, Codable {
    case pending
    case parsing       // 正在解析平台 URL
    case downloading
    case paused
    case completed
    case failed
    case cancelled
}

// MARK: - Video Format (画质/格式选项)
struct VideoFormat: Identifiable, Codable {
    let id: String           // 格式标识符
    let ext: String          // 文件扩展名
    let resolution: String   // 分辨率标签（如 "1080p"）
    let height: Int          // 像素高度
    let fileSize: Int64?     // 文件大小（字节）
    let hasAudio: Bool       // 是否包含音频
    let label: String        // 显示标签

    var displaySize: String {
        if let size = fileSize {
            return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
        }
        return "未知大小"
    }
}

// MARK: - Video Metadata (平台提取结果)
struct VideoMetadata: Codable {
    let platformId: String?      // 平台视频 ID
    let title: String
    let thumbnailURL: String?
    let duration: TimeInterval?
    let platform: String?        // 平台名称（youtube、bilibili、direct）
    let uploader: String?
    let formats: [VideoFormat]?  // 可选格式列表
    let directURL: String?       // 解析后的直接下载 URL
    let fileSize: Int64?

    var durationString: String? {
        guard let duration = duration else { return nil }
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Download Task
struct DownloadTask: Identifiable, Codable {
    let id: UUID
    var sourceType: DownloadSourceType
    var sourceURL: String           // 输入的 URL
    var title: String
    var status: DownloadStatus
    var progress: Double            // 0.0 to 1.0
    var localPath: String?          // 下载完成后的最终路径
    var temporaryPath: String?      // 下载中的临时文件路径
    var totalBytes: Int64?
    var downloadedBytes: Int64?
    var errorMessage: String?
    var createdAt: Date
    var completedAt: Date?

    // 平台提取结果（JSON 编码存储）
    var metadata: VideoMetadata?
    // 选中的格式
    var selectedFormat: VideoFormat?

    init(
        id: UUID = UUID(),
        sourceType: DownloadSourceType,
        sourceURL: String,
        title: String,
        status: DownloadStatus = .pending,
        progress: Double = 0,
        localPath: String? = nil,
        temporaryPath: String? = nil,
        totalBytes: Int64? = nil,
        downloadedBytes: Int64? = nil,
        errorMessage: String? = nil,
        createdAt: Date = Date(),
        completedAt: Date? = nil,
        metadata: VideoMetadata? = nil,
        selectedFormat: VideoFormat? = nil
    ) {
        self.id = id
        self.sourceType = sourceType
        self.sourceURL = sourceURL
        self.title = title
        self.status = status
        self.progress = progress
        self.localPath = localPath
        self.temporaryPath = temporaryPath
        self.totalBytes = totalBytes
        self.downloadedBytes = downloadedBytes
        self.errorMessage = errorMessage
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.metadata = metadata
        self.selectedFormat = selectedFormat
    }

    // MARK: Computed Properties
    var isActive: Bool {
        status == .downloading || status == .pending || status == .paused
    }

    var displayProgress: String {
        "\(Int(progress * 100))%"
    }

    var downloadedSizeFormatted: String {
        guard let downloaded = downloadedBytes else { return "0 B" }
        return ByteCountFormatter.string(fromByteCount: downloaded, countStyle: .file)
    }

    var totalSizeFormatted: String {
        guard let total = totalBytes else { return "未知" }
        return ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
    }

    var sourceLabel: String {
        switch sourceType {
        case .directURL: return "直链"
        case .platformURL: return metadata?.platform ?? "平台"
        }
    }
}
