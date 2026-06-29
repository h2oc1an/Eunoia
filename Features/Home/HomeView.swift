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
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Statistics Card
                    if let stats = statistics {
                        StatisticsCardView(statistics: stats)
                            .padding(.horizontal)
                    }

                    // Video List
                    VStack(alignment: .leading, spacing: 16) {
                        Text("视频")
                            .font(.headline)
                            .padding(.horizontal)

                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding()
                        } else if videos.isEmpty {
                            EmptyVideosView()
                        } else {
                            ScrollView {
                                LazyVStack(spacing: 16) {
                                    ForEach(videos) { video in
                                        HStack(spacing: 0) {
                                            VideoCardView(video: video)
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
                                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                            Button(role: .destructive) {
                                                deleteVideo(video)
                                            } label: {
                                                Label("删除", systemImage: "trash")
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Eunoia")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button(action: { showUploadSheet = true }) {
                            Label("上传本地视频", systemImage: "doc.fill")
                        }
                        Button(action: { showDownloadSheet = true }) {
                            Label("下载视频", systemImage: "arrow.down.circle.fill")
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
            }
            .refreshable {
                await loadData()
            }
            .onAppear {
                loadSampleDataIfNeeded()
            }
            .fullScreenCover(item: $selectedVideo) { video in
                VideoPlayerView(video: video)
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
                    // 上传完成后刷新数据
                    Task { @MainActor in
                        await loadData()
                    }
                }
            }
            .onChange(of: showDownloadSheet) { isPresented in
                if !isPresented {
                    // 下载完成后刷新数据
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
        }
    }

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

    /// 从 HomeView 长按菜单触发的转录
    private func startTranscriptionForHomeVideo(_ video: Video, mode: SubtitleMode) {
        TranscriptionTaskManager.shared.startTranscription(
            videoTitle: video.title,
            videoPath: video.localPath,
            subtitleMode: mode
        ) { result in
            switch result {
            case .success(let transcriptionResult):
                let subtitleDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                    .appendingPathComponent("Subtitles", isDirectory: true)
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

struct StatisticsCardView: View {
    let statistics: LearningStatistics

    var body: some View {
        HStack(spacing: 16) {
            StatItemView(
                icon: "book.fill",
                value: "\(statistics.totalWords)",
                label: "总单词",
                color: .blue
            )

            Divider()

            StatItemView(
                icon: "clock.fill",
                value: "\(statistics.wordsToReview)",
                label: "待复习",
                color: .orange
            )

            Divider()

            StatItemView(
                icon: "checkmark.circle.fill",
                value: "\(statistics.reviewedToday)",
                label: "今日已学",
                color: .green
            )
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
    }
}

struct StatItemView: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(value)
                .font(.title2)
                .fontWeight(.bold)

            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct VideoCardView: View {
    let video: Video

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Thumbnail with caching
            ZStack {
                CachedAsyncImage(path: video.thumbnailPath)

                // Play button overlay
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 44))
                    .foregroundColor(.white.opacity(0.9))

                // Duration badge
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text(formatDuration(video.duration))
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(4)
                    }
                }
                .padding(8)
            }
            .cornerRadius(8)

            VStack(alignment: .leading, spacing: 4) {
                Text(video.title)
                    .font(.headline)
                    .lineLimit(1)

                HStack {
                    if video.subtitlePath != nil {
                        Label("字幕", systemImage: "captions.bubble")
                            .font(.caption)
                    }
                    Spacer()
                }
                .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct EmptyVideosView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "film")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("暂无视频")
                .font(.headline)

            Text("请添加示例视频到 Resources/SampleVideos 目录")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}
