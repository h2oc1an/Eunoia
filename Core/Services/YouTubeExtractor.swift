import Foundation
import YouTubeKit

// MARK: - YouTube 提取器
/// 封装 YouTubeKit 库，从 YouTube 链接提取视频流信息
///
/// SPM 依赖: https://github.com/alexeichhorn/YouTubeKit
struct YouTubeExtractor: VideoExtractor {

    // MARK: - URL 检测
    static func canHandle(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }

        let youtubeDomains: Set<String> = [
            "www.youtube.com", "youtube.com",
            "m.youtube.com", "music.youtube.com",
            "youtu.be", "www.youtu.be",
            "youtube-nocookie.com", "www.youtube-nocookie.com"
        ]

        if youtubeDomains.contains(host) {
            return true
        }

        return false
    }

    // MARK: - 提取
    func extract(from url: URL) async throws -> ExtractionResult {
        // 提取视频 ID
        guard let videoID = extractVideoID(from: url) else {
            throw ExtractError.parseError("无法从 URL 提取 YouTube 视频 ID")
        }

        return try await extractWithYouTubeKit(videoID: videoID, originalURL: url)
    }

    // MARK: - YouTubeKit 集成
    private func extractWithYouTubeKit(videoID: String, originalURL: URL) async throws -> ExtractionResult {
        let video = YouTube(videoID: videoID)
        let streams = try await video.streams
        let metadata = try? await video.metadata

        // 筛选并分类流
        let progressiveStreams = streams.filter { $0.includesVideoAndAudioTrack && $0.isNativelyPlayable }
        let videoOnlyStreams = streams.filter { $0.includesVideoTrack && !$0.includesAudioTrack && $0.isNativelyPlayable }
        let audioOnlyStreams = streams.filter { $0.includesAudioTrack && !$0.includesVideoTrack && $0.isNativelyPlayable }

        // 转换为 VideoFormat
        var formats: [VideoFormat] = []

        // 视频+音频组合流（优先，按分辨率降序）
        for stream in progressiveStreams.sorted(by: { ($0.videoResolution ?? 0) > ($1.videoResolution ?? 0) }) {
            let resolution = stream.videoResolution.map { "\($0)p" } ?? "未知"
            formats.append(VideoFormat(
                id: stream.url.absoluteString,
                ext: stream.fileExtension.rawValue,
                resolution: resolution,
                height: stream.videoResolution ?? 0,
                fileSize: nil,
                hasAudio: true,
                label: "\(resolution) (含音频)"
            ))
        }

        // 仅视频流
        for stream in videoOnlyStreams.sorted(by: { ($0.videoResolution ?? 0) > ($1.videoResolution ?? 0) }).prefix(5) {
            let resolution = stream.videoResolution.map { "\($0)p" } ?? "未知"
            formats.append(VideoFormat(
                id: stream.url.absoluteString,
                ext: stream.fileExtension.rawValue,
                resolution: resolution,
                height: stream.videoResolution ?? 0,
                fileSize: nil,
                hasAudio: false,
                label: "\(resolution) (仅视频)"
            ))
        }

        // 仅音频流
        for stream in audioOnlyStreams.prefix(3) {
            let bitrate = stream.bitrate.map { "\($0/1000)kbps" } ?? ""
            formats.append(VideoFormat(
                id: stream.url.absoluteString,
                ext: stream.fileExtension.rawValue,
                resolution: "仅音频",
                height: 0,
                fileSize: nil,
                hasAudio: true,
                label: "音频 \(bitrate)"
            ))
        }

        // 选择最佳下载 URL：优先 progressive（含音频），选择最高分辨率
        let bestStream = progressiveStreams
            .max(by: { ($0.videoResolution ?? 0) < ($1.videoResolution ?? 0) })
        let directURL = bestStream?.url

        return ExtractionResult(
            title: metadata?.title ?? videoID,
            thumbnailURL: metadata?.thumbnail?.url,
            duration: nil,
            platform: "youtube",
            formats: formats,
            directURL: directURL,
            uploader: nil,
            fileSize: nil
        )
    }

    // MARK: - URL 解析辅助

    /// 从 YouTube URL 提取视频 ID
    private func extractVideoID(from url: URL) -> String? {
        let urlString = url.absoluteString
        let host = url.host?.lowercased() ?? ""

        // youtu.be/{videoID}
        if host == "youtu.be" || host == "www.youtu.be" {
            let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            if !path.isEmpty {
                return path.components(separatedBy: CharacterSet(charactersIn: "?&")).first
            }
        }

        // youtube.com/watch?v={videoID}
        if host.contains("youtube.com") {
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let queryItems = components.queryItems {
                // /watch?v=xxx
                if let vParam = queryItems.first(where: { $0.name == "v" })?.value {
                    return vParam
                }
            }

            // /embed/{videoID} or /shorts/{videoID} or /v/{videoID}
            let pathComponents = url.pathComponents
            if pathComponents.count >= 2 {
                let possiblePaths = ["embed", "shorts", "v"]
                for (i, component) in pathComponents.enumerated() {
                    if possiblePaths.contains(component.lowercased()), i + 1 < pathComponents.count {
                        return pathComponents[i + 1]
                    }
                }
            }
        }

        // 尝试从 URL 中匹配常见的 video ID 模式（11个字符，字母数字和下划线）
        let pattern = "[A-Za-z0-9_-]{11}"
        if let range = urlString.range(of: pattern, options: .regularExpression) {
            let match = String(urlString[range])
            // 过滤掉明显不是 video ID 的内容
            if !match.contains(".") && match.rangeOfCharacter(from: CharacterSet.letters) != nil {
                return match
            }
        }

        return nil
    }
}
