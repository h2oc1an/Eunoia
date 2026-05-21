import SwiftUI
import UniformTypeIdentifiers

struct UploadView: View {
    @StateObject private var viewModel = UploadViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showVideoPicker = false
    @State private var showSubtitlePicker = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 标题栏
                HStack {
                    Text("上传视频")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Color(hex: "1D1D1F"))

                    Spacer()

                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(Color(hex: "C7C7CC"))
                    }
                    .buttonStyle(.plain)
                }

                // 视频卡片
                videoCard

                // 字幕卡片
                subtitleCard

                // 信息卡片
                infoCard

                // 进度/消息
                if viewModel.isUploading {
                    progressCard
                }
                if let error = viewModel.errorMessage {
                    messageCard(error, color: "FF3B30")
                }
                if let success = viewModel.successMessage {
                    messageCard(success, color: "34C759")
                }

                // 底部按钮
                HStack(spacing: 12) {
                    Button(action: { dismiss() }) {
                        Text("取消")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(hex: "6E6E73"))
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(Color(hex: "F5F5F7"))
                            .cornerRadius(12)
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        Task {
                            if await viewModel.upload() {
                                dismiss()
                            }
                        }
                    }) {
                        Text("上传")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(viewModel.canUpload ? Color(hex: "007AFF") : Color(hex: "007AFF").opacity(0.5))
                            .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                    .disabled(!viewModel.canUpload)
                }
            }
            .padding(32)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(hex: "F5F5F7"))
        .sheet(isPresented: $showVideoPicker) {
            DocumentPickerView(
                supportedTypes: [.mpeg4Movie, .quickTimeMovie, .movie],
                pickerMode: .open
            ) { urls in
                if let url = urls.first {
                    viewModel.selectVideo(url: url)
                }
                showVideoPicker = false
            }
        }
        .sheet(isPresented: $showSubtitlePicker) {
            SubtitlePickerView { url in
                viewModel.selectSubtitle(url: url)
                showSubtitlePicker = false
            }
        }
    }

    // MARK: - 视频卡片
    private var videoCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("视频")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color(hex: "1D1D1F"))

            if let url = viewModel.selectedVideoURL {
                selectedVideoRow(url: url)

                Button(action: { viewModel.selectedVideoURL = nil }) {
                    HStack(spacing: 8) {
                        Image(systemName: "trash")
                            .font(.system(size: 14))
                        Text("移除视频")
                            .font(.system(size: 14))
                    }
                    .foregroundColor(Color(hex: "FF3B30"))
                }
                .buttonStyle(.plain)
            } else {
                Button(action: { showVideoPicker = true }) {
                    VStack(spacing: 12) {
                        Image(systemName: "arrow.up.circle")
                            .font(.system(size: 36))
                            .foregroundColor(Color(hex: "007AFF"))

                        Text("选择视频文件")
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "6E6E73"))

                        Text("支持 MP4、MOV 格式")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "8E8E93"))
                    }
                    .frame(maxWidth: .infinity, minHeight: 120)
                    .background(Color(hex: "F5F5F7"))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(hex: "E5E5EA"), lineWidth: 2)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(24)
        .background(Color.white)
        .cornerRadius(16)
    }

    private func selectedVideoRow(url: URL) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "film")
                .font(.system(size: 18))
                .foregroundColor(Color(hex: "007AFF"))
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(url.lastPathComponent)
                    .font(.system(size: 15))
                    .foregroundColor(Color(hex: "1D1D1F"))
                    .lineLimit(1)

                Text("已选择")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "8E8E93"))
            }

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18))
                .foregroundColor(Color(hex: "34C759"))
        }
        .padding(16)
        .background(Color(hex: "F5F5F7"))
        .cornerRadius(12)
    }

    // MARK: - 字幕卡片
    private var subtitleCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("字幕")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color(hex: "1D1D1F"))

            Button(action: { showSubtitlePicker = true }) {
                HStack(spacing: 12) {
                    Image(systemName: "captions.bubble")
                        .font(.system(size: 18))
                        .foregroundColor(Color(hex: "FF9500"))
                        .frame(width: 28)

                    Text(viewModel.selectedSubtitleURL?.lastPathComponent ?? "选择字幕文件（可选）")
                        .font(.system(size: 15))
                        .foregroundColor(Color(hex: "1D1D1F"))

                    Spacer()

                    if viewModel.selectedSubtitleURL != nil {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(Color(hex: "34C759"))
                    }
                }
                .padding(.vertical, 14)
            }
            .buttonStyle(.plain)

            if viewModel.selectedSubtitleURL != nil {
                Button(action: { viewModel.selectedSubtitleURL = nil }) {
                    HStack(spacing: 8) {
                        Image(systemName: "trash")
                            .font(.system(size: 14))
                        Text("移除字幕")
                            .font(.system(size: 14))
                    }
                    .foregroundColor(Color(hex: "FF3B30"))
                }
                .buttonStyle(.plain)

                Button(action: {
                    Task {
                        await viewModel.translateSubtitle()
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "character.bubble")
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "007AFF"))
                        Text("翻译字幕为中文")
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "007AFF"))
                        Spacer()
                        if viewModel.isTranslating {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .background(Color(hex: "F5F5F7"))
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isTranslating)

                if viewModel.isTranslating {
                    VStack(alignment: .leading, spacing: 8) {
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color(hex: "E5E5EA"))
                                .frame(height: 4)

                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color(hex: "007AFF"))
                                .frame(width: max(4, 200 * CGFloat(viewModel.translateProgress)), height: 4)
                        }
                        .frame(maxWidth: 200)

                        Text(viewModel.translateStatus)
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "8E8E93"))
                    }
                    .padding(.top, 4)
                }
            }
        }
        .padding(24)
        .background(Color.white)
        .cornerRadius(16)
    }

    // MARK: - 信息卡片
    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("信息")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color(hex: "1D1D1F"))

            TextField("视频标题", text: $viewModel.videoTitle)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .padding(12)
                .background(Color(hex: "F5F5F7"))
                .cornerRadius(10)
        }
        .padding(24)
        .background(Color.white)
        .cornerRadius(16)
    }

    // MARK: - 进度卡片
    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("上传进度")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color(hex: "1D1D1F"))

            HStack(spacing: 12) {
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(hex: "E5E5EA"))
                        .frame(height: 4)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(hex: "007AFF"))
                        .frame(width: max(4, 200 * CGFloat(viewModel.uploadProgress)), height: 4)
                }
                .frame(maxWidth: 200)

                Text("\(Int(viewModel.uploadProgress * 100))%")
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "8E8E93"))
            }
        }
        .padding(24)
        .background(Color.white)
        .cornerRadius(16)
    }

    private func messageCard(_ message: String, color: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: color == "FF3B30" ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .font(.system(size: 16))
                .foregroundColor(Color(hex: color))

            Text(message)
                .font(.system(size: 14))
                .foregroundColor(Color(hex: color))

            Spacer()
        }
        .padding(16)
        .background(Color(hex: color).opacity(0.08))
        .cornerRadius(12)
    }
}

#Preview {
    UploadView()
}
