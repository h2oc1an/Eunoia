import Foundation
import CryptoKit

// MARK: - Bilibili 提取器
/// 纯 Swift 实现 Bilibili 视频解析
///
/// 参考:
/// - SocialSisterYi/bilibili-API-collect (API 文档)
/// - Bilibili WBI 签名算法
///
/// 能力:
/// - 支持 BV 号、AV 号、b23.tv 短链接
/// - 支持 MP4 单文件和 DASH 分离流
/// - 自动 WBI 签名
struct BilibiliExtractor: VideoExtractor {

    /// Bilibili 域名集合
    private static let bilibiliDomains: Set<String> = [
        "www.bilibili.com", "bilibili.com",
        "m.bilibili.com", "b23.tv",
        "www.b23.tv", "t.bilibili.com"
    ]

    // MARK: - URL 检测
    static func canHandle(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }

        if bilibiliDomains.contains(host) {
            return true
        }

        let path = url.path.lowercased()
        return (host.hasSuffix("bilibili.com") || host.hasSuffix("b23.tv"))
            && (path.contains("video") || path.contains("bangumi") || path.hasPrefix("/BV") || path.hasPrefix("/av"))
    }

    // MARK: - 提取
    func extract(from url: URL) async throws -> ExtractionResult {
        // Step 1: 解析输入 URL，获取 BV 号
        var bvid: String?
        var pageIndex = 1

        if url.host?.lowercased() == "b23.tv" || url.host?.lowercased() == "www.b23.tv" {
            // b23.tv 短链接 → 跟随重定向
            bvid = try await resolveB23TV(url)
        } else if let bv = extractBVID(from: url) {
            bvid = bv
            // 提取分页参数
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let pItem = components.queryItems?.first(where: { $0.name == "p" }),
               let p = Int(pItem.value ?? "1") {
                pageIndex = p
            }
        } else {
            throw ExtractError.platformNotSupported("无法从 URL 提取 Bilibili 视频 ID")
        }

        guard let bvid = bvid else {
            throw ExtractError.platformNotSupported("无法解析 Bilibili 视频 ID")
        }

        // Step 2: 获取视频基本信息
        let videoInfo = try await fetchVideoInfo(bvid: bvid)

        // 确定目标 cid（支持分页）
        let pages = videoInfo.pages ?? []
        let targetPage = pages.first(where: { $0.page == pageIndex }) ?? pages.first

        guard let cid = targetPage?.cid else {
            throw ExtractError.parseError("未找到视频分页数据")
        }

        let title = targetPage?.part
            ?? videoInfo.title
            ?? "Bilibili 视频"

        // Step 3: 获取 WBI 密钥并生成签名
        let (mixinKey, wbiImgKey) = try await fetchWBIKeys()

        // Step 4: 获取视频流 URL
        let formats = try await fetchPlayURL(
            bvid: bvid,
            cid: cid,
            mixinKey: mixinKey,
            wbiImgKey: wbiImgKey
        )

        // 选择最佳直接 URL（首选 720p MP4）
        let directURL: URL?
        if let bestFormat = formats.first(where: { $0.hasAudio && $0.height >= 720 })
            ?? formats.first(where: { $0.hasAudio })
            ?? formats.first {
            directURL = URL(string: bestFormat.id)  // id 存储的是直接 URL
        } else {
            directURL = nil
        }

        return ExtractionResult(
            title: title,
            thumbnailURL: URL(string: videoInfo.pic ?? ""),
            duration: videoInfo.duration.map { TimeInterval($0) },
            platform: "bilibili",
            formats: formats,
            directURL: directURL,
            uploader: videoInfo.owner?.name,
            fileSize: nil
        )
    }

    // MARK: - URL 解析

    /// 从 URL 提取 BV 号（保留原始大小写）
    private func extractBVID(from url: URL) -> String? {
        let urlString = url.absoluteString

        // BV 号: 大小写敏感，用原字符串匹配
        if let range = urlString.range(of: "BV[a-zA-Z0-9]+", options: .regularExpression) {
            return String(urlString[range])
        }

        // bv 小写形式（某些短链接用）
        if let range = urlString.range(of: "bv[a-zA-Z0-9]+", options: .regularExpression) {
            return String(urlString[range])
        }

        // AV 号: /av12345
        if let range = urlString.range(of: "av[0-9]+", options: [.regularExpression, .caseInsensitive]) {
            return String(urlString[range])
        }

        return nil
    }

    /// 解析 b23.tv 短链接
    private func resolveB23TV(_ url: URL) async throws -> String? {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10

        // 不跟随重定向，手动获取 Location
        let session = URLSession(configuration: .default)
        let (_, response) = try await session.data(for: request)

        if let httpResponse = response as? HTTPURLResponse,
           httpResponse.statusCode == 302,
           let location = httpResponse.allHeaderFields["Location"] as? String,
           let redirectURL = URL(string: location) {
            return extractBVID(from: redirectURL)
        }

        return nil
    }

    // MARK: - API 调用

    /// 获取视频基本信息
    struct VideoInfoResponse: Decodable {
        struct Data: Decodable {
            let bvid: String?
            let aid: Int?
            let title: String?
            let pic: String?
            let duration: Int?
            let owner: Owner?
            let pages: [Page]?
        }
        struct Owner: Decodable {
            let name: String?
        }
        struct Page: Decodable {
            let cid: Int
            let page: Int
            let part: String?
        }
        let data: Data?
        let code: Int
        let message: String?
    }

    private func fetchVideoInfo(bvid: String) async throws -> VideoInfoResponse.Data {
        let urlString = "https://api.bilibili.com/x/web-interface/view?bvid=\(bvid)"
        guard let url = URL(string: urlString) else {
            throw ExtractError.parseError("无效的 API URL")
        }

        var request = URLRequest(url: url)
        request.setValue(
            "https://www.bilibili.com",
            forHTTPHeaderField: "Referer"
        )
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )
        request.timeoutInterval = 15

        let (data, _) = try await URLSession.shared.data(for: request)
        let decoder = JSONDecoder()
        let response = try decoder.decode(VideoInfoResponse.self, from: data)

        guard response.code == 0, let videoData = response.data else {
            throw ExtractError.parseError("视频信息获取失败 (code=\(response.code)): \(response.message ?? "未知错误")")
        }

        return videoData
    }

    // MARK: - WBI 签名

    /// WBI 密钥缓存
    private struct WBICache {
        static var imgKey: String?
        static var subKey: String?
        static var lastFetch: Date?
        static let ttl: TimeInterval = 3600 // 1 小时
    }

    /// 获取 WBI 密钥对
    private func fetchWBIKeys() async throws -> (mixinKey: String, imgKey: String) {
        // 检查缓存
        if let imgKey = WBICache.imgKey,
           let subKey = WBICache.subKey,
           let lastFetch = WBICache.lastFetch,
           Date().timeIntervalSince(lastFetch) < WBICache.ttl {
            let mixinKey = computeMixinKey(imgKey: imgKey, subKey: subKey)
            return (mixinKey, imgKey)
        }

        let url = URL(string: "https://api.bilibili.com/x/web-interface/nav")!
        var request = URLRequest(url: url)
        request.setValue("https://www.bilibili.com", forHTTPHeaderField: "Referer")
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )
        request.timeoutInterval = 15

        let (data, _) = try await URLSession.shared.data(for: request)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataDict = json["data"] as? [String: Any],
              let wbiImg = dataDict["wbi_img"] as? [String: Any],
              let imgURLStr = wbiImg["img_url"] as? String,
              let subURLStr = wbiImg["sub_url"] as? String else {
            throw ExtractError.parseError("无法获取 WBI 密钥")
        }

        // 从 URL 中提取文件名（移除扩展名和 / 前缀）
        let imgKey = extractKeyFromURL(imgURLStr)
        let subKey = extractKeyFromURL(subURLStr)

        guard !imgKey.isEmpty, !subKey.isEmpty else {
            throw ExtractError.parseError("WBI 密钥格式无效")
        }

        WBICache.imgKey = imgKey
        WBICache.subKey = subKey
        WBICache.lastFetch = Date()

        let mixinKey = computeMixinKey(imgKey: imgKey, subKey: subKey)
        return (mixinKey, imgKey)
    }

    /// 从 WBI 图片 URL 提取密钥
    private func extractKeyFromURL(_ urlStr: String) -> String {
        guard let url = URL(string: urlStr) else { return "" }
        let fileName = url.lastPathComponent
        return fileName.replacingOccurrences(of: ".png", with: "")
            .replacingOccurrences(of: ".jpg", with: "")
    }

    /// 计算混音密钥
    private func computeMixinKey(imgKey: String, subKey: String) -> String {
        let raw = imgKey + subKey
        let permute: [Int] = [
            46, 47, 18, 2, 53, 8, 23, 32, 15, 50, 10, 31, 58, 3, 45, 35,
            27, 43, 5, 49, 33, 9, 42, 19, 29, 28, 14, 39, 12, 38, 41, 13,
            37, 48, 7, 16, 24, 55, 40, 61, 26, 17, 0, 1, 60, 51, 30, 4,
            22, 25, 54, 21, 56, 59, 6, 63, 57, 62, 11, 36, 20, 34, 44, 52
        ]

        let chars = Array(raw)
        var result = ""
        for pos in permute {
            if pos < chars.count {
                result.append(chars[pos])
            }
        }
        return String(result.prefix(32))
    }

    /// 生成 WBI 签名参数
    private func signWBI(params: [String: Any], mixinKey: String) -> (w_rid: String, wts: String) {
        let wts = String(Int(Date().timeIntervalSince1970))

        // 按 key 排序
        var allParams = params
        allParams["wts"] = wts

        let sortedKeys = allParams.keys.sorted()
        var queryString = ""
        for key in sortedKeys {
            if let value = allParams[key] {
                let encodedValue = "\(value)".urlEncoded()
                if !queryString.isEmpty { queryString += "&" }
                queryString += "\(key)=\(encodedValue)"
            }
        }

        // 附加 mixin key 并计算 MD5
        let signString = queryString + mixinKey
        let wrid = MD5(string: signString)

        return (wrid, wts)
    }

    // MARK: - 获取播放流 URL

    struct PlayURLResponse: Decodable {
        struct Data: Decodable {
            struct DashInfo: Decodable {
                let video: [DashStream]?
                let audio: [DashStream]?
            }
            struct DashStream: Decodable {
                let id: Int
                let baseUrl: String?
                let backupUrl: [String]?
                let bandwidth: Int?
                let codecs: String?
                let width: Int?
                let height: Int?
                let frameRate: String?
            }
            let durl: [MP4Stream]?
            let dash: DashInfo?
            let quality: Int?
            let accept_quality: [Int]?
            let accept_description: [String]?
        }
        struct MP4Stream: Decodable {
            let url: String?
            let size: Int64?
            let length: Int?
        }
        let data: Data?
        let code: Int
        let message: String?
    }

    /// 质量标签映射
    private let qualityLabels: [Int: String] = [
        127: "8K", 125: "HDR", 120: "4K", 116: "1080p60",
        112: "1080p+", 80: "1080p", 74: "720p60", 64: "720p",
        48: "720p", 32: "480p", 16: "360p", 6: "240p"
    ]

    private func fetchPlayURL(
        bvid: String, cid: Int, mixinKey: String, wbiImgKey: String
    ) async throws -> [VideoFormat] {
        // 构建基础参数（使用 SortedDictionary 保证字母序）
        let wts = String(Int(Date().timeIntervalSince1970))
        let params: [(String, String)] = [
            ("bvid", bvid),
            ("cid", String(cid)),
            ("fnval", "1"),      // MP4 单文件流
            ("fnver", "0"),
            ("fourk", "0"),
            ("high_quality", "1"),
            ("platform", "web"),
            ("qn", "80"),        // 1080p
            ("wts", wts)
        ].sorted { $0.0 < $1.0 }

        // 用与签名完全一致的编码方式构建 query string
        let queryString = params.map { "\($0.0)=\($0.1.urlEncoded())" }.joined(separator: "&")
        let wrid = MD5(string: queryString + mixinKey)

        // 手动拼接完整 URL
        let urlString = "https://api.bilibili.com/x/player/wbi/playurl?\(queryString)&w_rid=\(wrid)"
        guard let url = URL(string: urlString) else {
            throw ExtractError.parseError("无效的播放 API URL")
        }

        var request = URLRequest(url: url)
        request.setValue("https://www.bilibili.com", forHTTPHeaderField: "Referer")
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )
        request.timeoutInterval = 15

        let (data, _) = try await URLSession.shared.data(for: request)
        let decoder = JSONDecoder()
        let response = try decoder.decode(PlayURLResponse.self, from: data)

        guard response.code == 0, let playData = response.data else {
            throw ExtractError.parseError("播放地址获取失败 (code=\(response.code)): \(response.message ?? "未知错误")")
        }

        var formats: [VideoFormat] = []

        // MP4 单文件流
        if let durl = playData.durl {
            for stream in durl {
                if let urlStr = stream.url {
                    let quality = qualityLabels[playData.quality ?? 0] ?? "1080p"
                    formats.append(VideoFormat(
                        id: urlStr,
                        ext: "mp4",
                        resolution: quality,
                        height: 0,
                        fileSize: stream.size,
                        hasAudio: true,
                        label: "\(quality) MP4"
                    ))
                }
            }
        }

        // DASH 分离流（备用）
        if let dash = playData.dash {
            if let videoStreams = dash.video {
                for stream in videoStreams {
                    let urlStr = stream.baseUrl ?? stream.backupUrl?.first
                    guard let urlStr = urlStr else { continue }
                    let height = stream.height ?? 0
                    let quality = qualityLabels[stream.id] ?? "\(height)p"
                    formats.append(VideoFormat(
                        id: urlStr, ext: "mp4", resolution: quality, height: height,
                        fileSize: nil, hasAudio: false,
                        label: "\(quality) (仅视频)"
                    ))
                }
            }
            if let audioStreams = dash.audio {
                for stream in audioStreams {
                    let urlStr = stream.baseUrl ?? stream.backupUrl?.first
                    guard let urlStr = urlStr else { continue }
                    let bandwidth = (stream.bandwidth ?? 0) / 1000
                    formats.append(VideoFormat(
                        id: urlStr, ext: "m4a", resolution: "仅音频", height: 0,
                        fileSize: nil, hasAudio: true,
                        label: "音频 \(bandwidth)kbps"
                    ))
                }
            }
        }

        if formats.isEmpty {
            throw ExtractError.parseError("未找到可用的视频流")
        }

        return formats
    }
}

// MARK: - 辅助函数

/// MD5 哈希
private func MD5(string: String) -> String {
    let hash = Insecure.MD5.hash(data: string.data(using: .utf8) ?? Data())
    return hash.map { String(format: "%02x", $0) }.joined()
}

/// URL 编码（大写的十六进制，符合 Bilibili WBI 规范）
private extension String {
    func urlEncoded() -> String {
        let allowedChars = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        return self.addingPercentEncoding(withAllowedCharacters: allowedChars) ?? self
    }
}

/// JSON 编解码辅助
private extension Encodable {
    func asDictionary() -> [String: Any]? {
        guard let data = try? JSONEncoder().encode(self),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return dict
    }
}
