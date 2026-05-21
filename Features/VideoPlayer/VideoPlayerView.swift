import SwiftUI
import AVKit
#if os(macOS)
import AppKit
#endif

struct VideoPlayerView: View {
    let video: Video
    @StateObject private var viewModel: VideoPlayerViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var hasInitialized = false
    @State private var showSubtitleShare = false
    @State private var showSubtitlePicker = false
    #if os(macOS)
    @State private var keyMonitor: Any?
    #endif

    init(video: Video) {
        self.video = video
        _viewModel = StateObject(wrappedValue: VideoPlayerViewModel(video: video))
    }

    var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height

            ZStack {
                Color.black.ignoresSafeArea()

                if isLandscape {
                    landscapeLayout(geometry: geometry)
                } else {
                    portraitLayout(geometry: geometry)
                }
            }
        }
        .sheet(isPresented: $showSubtitleShare) {
            if let subtitlePath = video.subtitlePath {
                SubtitleShareView(subtitlePath: subtitlePath, videoTitle: video.title)
            }
        }
        .sheet(isPresented: $viewModel.showingBookmarkSheet) {
            BookmarkListSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showingAddBookmark) {
            AddBookmarkSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $showSubtitlePicker) {
            SubtitleModePickerView { mode in
                viewModel.startTranscription(mode: mode)
            }
        }
        .onAppear {
            if !hasInitialized {
                hasInitialized = true
                viewModel.setupPlayer(with: video)
            }
            #if os(macOS)
            keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if event.keyCode == 53 {
                    dismiss()
                    return nil
                }
                return event
            }
            #endif
        }
        .onDisappear {
            viewModel.cleanup()
            #if os(macOS)
            if let monitor = keyMonitor {
                NSEvent.removeMonitor(monitor)
                keyMonitor = nil
            }
            #endif
        }
    }

    // MARK: - Portrait Layout
    @ViewBuilder
    private func portraitLayout(geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()

                // 书签按钮
                Button(action: { viewModel.showingBookmarkSheet = true }) {
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(8)
                }
                .padding(.trailing, 8)

                // 添加书签按钮
                Button(action: { viewModel.showingAddBookmark = true }) {
                    Image(systemName: "bookmark.badge.plus")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(8)
                }
                .padding(.trailing, 4)

                // 字幕生成按钮（无字幕时显示）
                if !viewModel.hasSubtitles {
                    if viewModel.isTranscribing {
                        ProgressView()
                            .tint(.white)
                            .padding(.trailing, 16)
                            .padding(.top, 8)
                    } else {
                        Button(action: { showSubtitlePicker = true }) {
                            Image(systemName: "captions.bubble")
                                .font(.system(size: 18))
                                .foregroundColor(.white)
                                .padding(8)
                                .background(Color.white.opacity(0.2))
                                .cornerRadius(8)
                        }
                        .padding(.trailing, 16)
                        .padding(.top, 8)
                    }
                } else {
                    Spacer().frame(width: 8)
                }
            }

            PlatformVideoPlayer(player: viewModel.player)
                .frame(height: geometry.size.height * 0.35)
                .overlay(
                    VideoGestureView(
                        onSeek: { delta in
                            let newTime = max(0, min(viewModel.duration, viewModel.currentTime + delta))
                            viewModel.seek(to: newTime)
                        },
                        onDoubleTap: {
                            viewModel.togglePlayPause()
                        }
                    )
                )

            // Minimal Subtitle (no background, with shadow)
            MinimalSubtitleView(
                currentSubtitle: viewModel.currentSubtitle,
                onWordTap: { word in
                    viewModel.handleWordTap(word)
                }
            )
            .padding(.horizontal)

            Spacer()

        }

        wordPopupOverlay
    }

    // MARK: - Landscape Layout (Fullscreen Video)
    @ViewBuilder
    private func landscapeLayout(geometry: GeometryProxy) -> some View {
        ZStack {
            PlatformVideoPlayer(player: viewModel.player)
                .ignoresSafeArea()

            VStack {
                Spacer()

                MinimalSubtitleView(
                    currentSubtitle: viewModel.currentSubtitle,
                    onWordTap: { word in
                        viewModel.handleWordTap(word)
                    }
                )
                .padding(.horizontal, 40)
                .padding(.bottom, 50)
            }

        }

        wordPopupOverlay
    }

    // MARK: - Word Popup
    @ViewBuilder
    private var wordPopupOverlay: some View {
        if viewModel.showingWordPopup, let word = viewModel.selectedWord {
            WordPopupView(
                word: word,
                meaning: viewModel.selectedWordMeaning,
                context: viewModel.currentSubtitle?.text,
                onAddToVocabulary: {
                    viewModel.addToVocabulary()
                },
                onDismiss: {
                    viewModel.dismissWordPopup()
                }
            )
            .transition(.opacity)
        }
    }
}
