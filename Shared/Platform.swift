import Foundation
#if os(macOS)
import AppKit
public typealias PlatformImage = NSImage
#else
import UIKit
public typealias PlatformImage = UIImage
#endif

/// 平台抽象层，统一 iOS/macOS 差异
enum Platform {

    /// 应用基础目录
    static var baseURL: URL {
        #if os(macOS)
        let url = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Eunoia")
        #else
        let url = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask).first!
        #endif

        // 确保目录存在
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// 数据库目录
    static var databaseURL: URL {
        let url = baseURL.appendingPathComponent("Database", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url.appendingPathComponent("Eunoia.sqlite3")
    }

    /// 下载目录
    static var downloadsURL: URL {
        let url = baseURL.appendingPathComponent("Downloads", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// 字幕目录
    static var subtitlesURL: URL {
        let url = baseURL.appendingPathComponent("Subtitles", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// 视频目录
    static var videosURL: URL {
        let url = baseURL.appendingPathComponent("Videos", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// 缩略图目录
    static var thumbnailsURL: URL {
        let url = baseURL.appendingPathComponent("Thumbnails", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// 临时目录
    static var tempURL: URL {
        FileManager.default.temporaryDirectory
    }

    /// 缓存目录
    static var cacheURL: URL {
        let url = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Eunoia", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

// MARK: - PlatformImage 工厂方法

/// 从 CGImage 创建 PlatformImage（统一返回可选类型）
func makePlatformImage(cgImage: CGImage) -> PlatformImage? {
    #if os(macOS)
    return NSImage(cgImage: cgImage, size: .zero)
    #else
    return UIImage(cgImage: cgImage)
    #endif
}

// MARK: - PlatformImage 扩展

#if os(macOS)
extension NSImage {
    var cgImage: CGImage? {
        var rect = NSRect(origin: .zero, size: size)
        return cgImage(forProposedRect: &rect, context: nil, hints: nil)
    }

    func jpegData(compressionQuality: CGFloat) -> Data? {
        guard let cgImage = self.cgImage else { return nil }
        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        return bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: compressionQuality])
    }
}
#else
extension UIImage {
    var platformImage: UIImage { self }
}
#endif
