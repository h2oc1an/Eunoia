import SwiftUI

struct HomeView: View {
    @State private var videos: [Video] = []
    @State private var statistics: LearningStatistics?
    @State private var selectedVideo: Video?
    @State private var isLoading: Bool = true
    @State private var showUploadSheet: Bool = false
    @State private var showDownloadSheet: Bool = false
    @State private var showSubtitlePicker: Bool = false
    @State private var subtitleTargetVideo: Video?
    @State private var showTranscribeAlert: Bool = false
    @State private var transcribeAlertMessage: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 标题栏
                HStack {
                    Text("首页")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Color(hex: "1D1D1F"))

                    Spacer()

                    HStack(spacing: 0) {
                        Button(action: { Task { await loadData() } }) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 13))
                                .foregroundColor(Color(hex: "6E6E73"))
                                .frame(width: 32, height: 32)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        Divider()
                            .frame(height: 16)

                        Button(action: { showUploadSheet = true }) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.up.doc")
                                    .font(.system(size: 12))
                                Text("上传")
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .foregroundColor(Color(hex: "007AFF"))
                            .frame(height: 32)
                            .padding(.horizontal, 10)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        Button(action: { showDownloadSheet = true }) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.down.circle")
                                    .font(.system(size: 12))
                                Text("下载")
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .foregroundColor(Color(hex: "007AFF"))
                            .frame(height: 32)
                            .padding(.horizontal, 10)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(4)
                    .background(Color.white)
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(hex: "E5E5EA"), lineWidth: 1)
                    )
                }

                // 统计卡片
                if let stats = statistics {
                    statsCard(stats)
                }

                // 视频列表区域
                videoSection
            }
            .padding(32)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(hex: "F5F5F7"))
        .sheet(item: $selectedVideo) { video in
            VideoPlayerView(video: video)
                .frame(minWidth: 800, minHeight: 600)
        }
        .sheet(isPresented: $showUploadSheet) {
            UploadView()
        }
        .sheet(isPresented: $showDownloadSheet) {
            DownloadView()
        }
        .sheet(isPresented: $showSubtitlePicker) {
            SubtitleModePickerView { mode in
                if let video = subtitleTargetVideo {
                    startTranscriptionForHomeVideo(video, mode: mode)
                }
            }
        }
        .onChange(of: showUploadSheet) { isPresented in
            if !isPresented {
                Task { @MainActor in
                    await loadData()
                }
            }
        }
        .onChange(of: showDownloadSheet) { isPresented in
            if !isPresented {
                Task { @MainActor in
                    await loadData()
                }
            }
        }
        .alert("转录任务", isPresented: $showTranscribeAlert) {
            Button("好的", role: .cancel) {}
        } message: {
            Text(transcribeAlertMessage)
        }
        .onAppear {
            loadSampleDataIfNeeded()
        }
    }

    // MARK: - 统计卡片
    private func statsCard(_ stats: LearningStatistics) -> some View {
        HStack(spacing: 0) {
            statItem(value: "\(stats.totalWords)", label: "总单词数", color: "007AFF")
            Divider()
                .frame(height: 40)
            statItem(value: "\(stats.wordsToReview)", label: "待复习", color: "FF9500")
            Divider()
                .frame(height: 40)
            statItem(value: "\(stats.reviewedToday)", label: "今日已学", color: "34C759")
        }
        .padding(24)
        .background(Color.white)
        .cornerRadius(16)
    }

    private func statItem(value: String, label: String, color: String) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(Color(hex: color))

            Text(label)
                .font(.system(size: 13))
                .foregroundColor(Color(hex: "8E8E93"))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 视频列表区域
    @ViewBuilder
    private var videoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("视频")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color(hex: "1D1D1F"))

                Spacer()

                if !videos.isEmpty {
                    Text("\(videos.count) 个视频")
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "8E8E93"))
                }
            }

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            } else if videos.isEmpty {
                emptyState
            } else {
                VStack(spacing: 12) {
                    ForEach(videos) { video in
                        VideoListRow(video: video)
                            .onTapGesture {
                                selectedVideo = video
                            }
                            .contextMenu {
                                if video.subtitlePath == nil {
                                    Button {
                                        subtitleTargetVideo = video
                                        showSubtitlePicker = true
                                    } label: {
                                        Label("生成字幕", systemImage: "captions.bubble")
                                    }
                                }
                                Button(role: .destructive) {
                                    deleteVideo(video)
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                    }
                }
            }
        }
    }

    // MARK: - 空状态
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "film")
                .font(.system(size: 50))
                .foregroundColor(Color(hex: "C7C7CC"))

            Text("暂无视频")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color(hex: "8E8E93"))

            Text("点击右上角添加视频开始学习")
                .font(.system(size: 13))
                .foregroundColor(Color(hex: "C7C7CC"))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
    }

    // MARK: - Actions

    private func loadSampleDataIfNeeded() {
        do {
            try VideoService.shared.loadSampleVideos()
            Task { @MainActor in
                await loadData()
            }
        } catch {
            print("Failed to load sample videos: \(error)")
        }
    }

    @MainActor
    private func loadData() async {
        isLoading = true
        do {
            videos = try VideoService.shared.getAllVideos()
            statistics = try VocabularyService.shared.getStatistics()
        } catch {
            print("Failed to load data: \(error)")
        }
        isLoading = false
    }

    @MainActor
    private func deleteVideo(_ video: Video) {
        do {
            try VideoService.shared.deleteVideo(video)
            videos.removeAll { $0.id == video.id }
            statistics = try VocabularyService.shared.getStatistics()
        } catch {
            print("Failed to delete video: \(error)")
        }
    }

    private func startTranscriptionForHomeVideo(_ video: Video, mode: SubtitleMode) {
        TranscriptionTaskManager.shared.startTranscription(
            videoTitle: video.title,
            videoPath: video.localPath,
            subtitleMode: mode
        ) { result in
            switch result {
            case .success(let transcriptionResult):
                let subtitleDir = Platform.subtitlesURL
                try? FileManager.default.createDirectory(at: subtitleDir, withIntermediateDirectories: true)

                let destURL = subtitleDir.appendingPathComponent("\(video.id.uuidString).srt")
                try? FileManager.default.removeItem(at: destURL)
                if let _ = try? FileManager.default.copyItem(atPath: transcriptionResult.subtitlePath, toPath: destURL.path) {
                    var updatedVideo = video
                    updatedVideo.subtitlePath = destURL.path
                    try? VideoRepository.shared.update(updatedVideo)
                }
            case .failure:
                break
            }
        }
        transcribeAlertMessage = "已创建转录任务，可前往「转录」页面查看进度"
        showTranscribeAlert = true
    }
}

// MARK: - 视频列表行

struct VideoListRow: View {
    let video: Video

    var body: some View {
        HStack(spacing: 16) {
            // 缩略图
            ZStack {
                if let thumbnailPath = video.thumbnailPath {
                    CachedAsyncImage(path: thumbnailPath)
                        .frame(width: 160, height: 90)
                        .cornerRadius(8)
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hex: "F5F5F7"))
                        .frame(width: 160, height: 90)
                        .overlay(
                            Image(systemName: "film")
                                .font(.system(size: 24))
                                .foregroundColor(Color(hex: "C7C7CC"))
                        )
                }

                Image(systemName: "play.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.white.opacity(0.9))

                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text(formatDuration(video.duration))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(4)
                    }
                }
                .padding(6)
            }
            .frame(width: 160, height: 90)

            // 视频信息
            VStack(alignment: .leading, spacing: 8) {
                Text(video.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(hex: "1D1D1F"))
                    .lineLimit(2)

                HStack(spacing: 4) {
                    if video.subtitlePath != nil {
                        Image(systemName: "captions.bubble")
                            .font(.system(size: 11))
                        Text("已字幕")
                            .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(hex: "34C759"))
                    } else {
                        Image(systemName: "captions.bubble.slash")
                            .font(.system(size: 11))
                        Text("无字幕")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "8E8E93"))
                    }
                }

                if let lastPlayed = video.lastPlayedAt {
                    Text("上次观看: \(lastPlayed, style: .relative)前")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "C7C7CC"))
                }
            }

            Spacer()
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(12)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
