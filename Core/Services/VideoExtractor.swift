import Foundation

// MARK: - 提取结果
struct ExtractionResult {
    let title: String
    let thumbnailURL: URL?
    let duration: TimeInterval?
    let platform: String
    let formats: [VideoFormat]
    let directURL: URL?       // 单文件直链（如 MP4）
    let uploader: String?
    let fileSize: Int64?

    init(
        title: String,
        thumbnailURL: URL? = nil,
        duration: TimeInterval? = nil,
        platform: String,
        formats: [VideoFormat] = [],
        directURL: URL? = nil,
        uploader: String? = nil,
        fileSize: Int64? = nil
    ) {
        self.title = title
        self.thumbnailURL = thumbnailURL
        self.duration = duration
        self.platform = platform
        self.formats = formats
        self.directURL = directURL
        self.uploader = uploader
        self.fileSize = fileSize
    }
}

// MARK: - 提取器协议
protocol VideoExtractor {
    /// 判断能否处理该 URL
    static func canHandle(_ url: URL) -> Bool

    /// 从 URL 提取视频信息
    func extract(from url: URL) async throws -> ExtractionResult
}

// MARK: - 直接 URL 提取器
/// 处理直接视频文件链接（.mp4, .mkv, .mov, .m3u8 等）
struct DirectURLExtractor: VideoExtractor {
    private static let videoExtensions: Set<String> = [
        "mp4", "mkv", "mov", "avi", "webm", "flv", "wmv",
        "m4v", "3gp", "ts", "m3u8", "mpd"
    ]

    static func canHandle(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            return false
        }

        let ext = url.pathExtension.lowercased()
        return videoExtensions.contains(ext)
            || url.lastPathComponent.lowercased().hasSuffix(".mp4")
            || url.lastPathComponent.lowercased().hasSuffix(".mkv")
    }

    func extract(from url: URL) async throws -> ExtractionResult {
        // 从 URL 推断文件名
        let fileName = url.deletingPathExtension().lastPathComponent
        let title = fileName.removingPercentEncoding ?? fileName

        let ext = url.pathExtension.lowercased()
        let isM3U8 = ext == "m3u8"

        // HEAD 请求获取文件大小和类型
        var fileSize: Int64?
        var contentType: String?

        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 15

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                fileSize = httpResponse.expectedContentLength > 0
                    ? httpResponse.expectedContentLength : nil
                contentType = (httpResponse.allHeaderFields["Content-Type"] as? String)
                    ?? (httpResponse.allHeaderFields["content-type"] as? String)
            }
        } catch {
            // HEAD 失败不阻塞解析，继续
            print("[DirectURLExtractor] HEAD request failed: \(error)")
        }

        // 生成格式列表
        let format: VideoFormat
        if isM3U8 {
            format = VideoFormat(
                id: "hls",
                ext: ext,
                resolution: "自适应",
                height: 0,
                fileSize: fileSize,
                hasAudio: true,
                label: "HLS 流"
            )
        } else {
            format = VideoFormat(
                id: "direct",
                ext: ext,
                resolution: contentType ?? "视频文件",
                height: 0,
                fileSize: fileSize,
                hasAudio: true,
                label: "原始文件"
            )
        }

        return ExtractionResult(
            title: title,
            thumbnailURL: nil,
            duration: nil,
            platform: "direct",
            formats: [format],
            directURL: url,
            uploader: nil,
            fileSize: fileSize
        )
    }
}

// MARK: - Cobalt 提取器（兜底方案）
/// 使用 Cobalt.tools 开放 API 解析多平台视频链接
/// API 文档: https://github.com/imputnet/cobalt
struct CobaltExtractor: VideoExtractor {
    private static let cobaltAPIURL = "https://api.cobalt.tools/api/json"

    static func canHandle(_ url: URL) -> Bool {
        // Cobalt 可作为兜底提取器，尝试处理任何 HTTP/HTTPS URL
        guard let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            return false
        }
        // 排除已由直接 URL 提取器处理的链接
        return !DirectURLExtractor.canHandle(url)
    }

    func extract(from url: URL) async throws -> ExtractionResult {
        var request = URLRequest(url: URL(string: Self.cobaltAPIURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        let body: [String: Any] = [
            "url": url.absoluteString,
            "filenamePattern": "basic",
            "alwaysProxy": true
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw ExtractError.platformNotSupported(
                "Cobalt API 返回错误 (HTTP \(statusCode))"
            )
        }

        // 解析响应
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ExtractError.parseError("无法解析 Cobalt API 响应")
        }

        // 检查错误
        if let errorMsg = json["error"] as? String {
            throw ExtractError.platformNotSupported(errorMsg)
        }

        // 提取直接 URL
        guard let directURLStr = json["url"] as? String,
              let directURL = URL(string: directURLStr) else {
            throw ExtractError.parseError("Cobalt 响应中未找到下载链接")
        }

        // 提取元信息
        let title = (json["filename"] as? String)
            ?? url.deletingPathExtension().lastPathComponent

        return ExtractionResult(
            title: title,
            thumbnailURL: nil,
            duration: nil,
            platform: "cobalt",
            formats: [
                VideoFormat(
                    id: "cobalt",
                    ext: "mp4",
                    resolution: directURL.lastPathComponent.contains("audio")
                        ? "仅音频" : "视频",
                    height: 0,
                    fileSize: nil,
                    hasAudio: true,
                    label: "Cobalt 解析"
                )
            ],
            directURL: directURL,
            uploader: nil,
            fileSize: nil
        )
    }
}

// MARK: - 提取器解析错误
enum ExtractError: LocalizedError {
    case platformNotSupported(String)
    case parseError(String)
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .platformNotSupported(let msg): return "不支持该平台: \(msg)"
        case .parseError(let msg): return "解析失败: \(msg)"
        case .networkError(let msg): return "网络错误: \(msg)"
        }
    }
}
