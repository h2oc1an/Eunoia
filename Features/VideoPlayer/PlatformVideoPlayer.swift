import SwiftUI
import AVKit
import AppKit

/// macOS 原生视频播放器视图
/// 使用 AVPlayerView 保留系统原生控制条，controlsStyle 设为 inline
struct PlatformVideoPlayer: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> AVPlayerView {
        let playerView = AVPlayerView()
        playerView.player = player
        playerView.controlsStyle = .inline
        playerView.showsSharingServiceButton = false
        playerView.showsFullScreenToggleButton = false
        playerView.allowsPictureInPicturePlayback = false
        return playerView
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        nsView.player = player
    }
}
