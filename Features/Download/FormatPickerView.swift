import SwiftUI

// MARK: - Format Picker View
/// 视频格式/画质选择界面
struct FormatPickerView: View {
    let formats: [VideoFormat]
    @Binding var selectedFormat: VideoFormat?
    let onConfirm: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(formats) { format in
                        FormatRow(
                            format: format,
                            isSelected: selectedFormat?.id == format.id,
                            onSelect: { selectedFormat = format }
                        )
                    }
                } header: {
                    Text("选择画质")
                } footer: {
                    if let format = selectedFormat {
                        Text("已选: \(format.label)\(format.fileSize != nil ? " · \(format.displaySize)" : "")")
                    }
                }
            }
            .navigationTitle("画质选择")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("下载") {
                        onConfirm()
                    }
                    .disabled(selectedFormat == nil)
                }
            }
        }
    }
}

// MARK: - Format Row
struct FormatRow: View {
    let format: VideoFormat
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // 选择指示器
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .gray)
                    .font(.title3)

                // 格式信息
                VStack(alignment: .leading, spacing: 2) {
                    Text(format.resolution)
                        .font(.headline)

                    Text(format.label)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(format.ext.uppercased())
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(4)

                    if format.fileSize != nil {
                        Text(format.displaySize)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                // 音频标识
                if format.hasAudio {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.caption2)
                        .foregroundColor(.green)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    FormatPickerView(
        formats: [
            VideoFormat(
                id: "f1", ext: "mp4", resolution: "1080p", height: 1080,
                fileSize: 500_000_000, hasAudio: true, label: "1080p (含音频)"
            ),
            VideoFormat(
                id: "f2", ext: "mp4", resolution: "720p", height: 720,
                fileSize: 300_000_000, hasAudio: true, label: "720p (含音频)"
            ),
            VideoFormat(
                id: "f3", ext: "mp4", resolution: "360p", height: 360,
                fileSize: 100_000_000, hasAudio: false, label: "360p (仅视频)"
            )
        ],
        selectedFormat: .constant(nil),
        onConfirm: {}
    )
}
