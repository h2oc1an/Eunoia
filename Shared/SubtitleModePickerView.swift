import SwiftUI

// MARK: - Subtitle Mode Picker View
/// 可复用的字幕模式选择 Sheet
struct SubtitleModePickerView: View {
    let onSelect: (SubtitleMode) -> Void

    @Environment(\.dismiss) private var dismiss

    // 展示用的模式列表（双语 / 原语言 / 仅中文）
    private let displayModes: [SubtitleMode] = [.bilingual, .original, .chinese]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(displayModes, id: \.self) { mode in
                        Button(action: {
                            onSelect(mode)
                            dismiss()
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: mode.iconName)
                                    .foregroundColor(mode.iconColor)
                                    .font(.title3)
                                    .frame(width: 28)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(mode.displayName)
                                        .font(.body)
                                    Text(mode.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                if mode == .bilingual {
                                    Text("推荐")
                                        .font(.caption2)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.blue)
                                        .cornerRadius(4)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("选择字幕模式")
                } footer: {
                    Text("WhisperKit 将自动检测视频语言。双语模式会将原文翻译为中文。")
                }
            }
            .navigationTitle("字幕模式")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
}

// MARK: - SubtitleMode UI Extension
extension SubtitleMode {
    var iconName: String {
        switch self {
        case .original: return "text.bubble"
        case .chinese: return "text.bubble.fill"
        case .bilingual: return "text.bubble.fill.rtl"
        }
    }

    var iconColor: Color {
        switch self {
        case .original: return .blue
        case .chinese: return .orange
        case .bilingual: return .purple
        }
    }

    var description: String {
        switch self {
        case .original: return "仅保留转录的原文"
        case .chinese: return "翻译为中文，替换原文"
        case .bilingual: return "原文 + 中文翻译（推荐）"
        }
    }
}

#Preview {
    SubtitleModePickerView { mode in
        print("Selected: \(mode.displayName)")
    }
}
