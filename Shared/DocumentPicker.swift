import SwiftUI
import UniformTypeIdentifiers

// MARK: - Document Picker

#if os(macOS)

enum DocumentPickerMode {
    case open
    case importFile
}

/// macOS 文件选择器
struct DocumentPickerView: View {
    let supportedTypes: [UTType]
    let pickerMode: DocumentPickerMode
    let onPick: ([URL]) -> Void

    var body: some View {
        MacFilePicker(supportedTypes: supportedTypes, onPick: onPick)
    }
}

struct MacFilePicker: View {
    let supportedTypes: [UTType]
    let onPick: ([URL]) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack {
            Text("选择文件")
                .font(.headline)
                .padding()

            Button("打开文件选择器") {
                let panel = NSOpenPanel()
                panel.allowsMultipleSelection = false
                panel.canChooseDirectories = false
                panel.canChooseFiles = true
                panel.allowedContentTypes = supportedTypes

                if panel.runModal() == .OK, let url = panel.url {
                    let tempURL = copyToTemp(url: url)
                    onPick([tempURL])
                    dismiss()
                }
            }
            .padding()

            Button("取消") {
                dismiss()
            }
            .padding()
        }
        .frame(width: 300, height: 200)
    }

    private func copyToTemp(url: URL) -> URL {
        let originalFileName = url.lastPathComponent
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(originalFileName)

        do {
            if FileManager.default.fileExists(atPath: tempURL.path) {
                try FileManager.default.removeItem(at: tempURL)
            }
            try FileManager.default.copyItem(at: url, to: tempURL)
        } catch {
            print("Failed to copy file: \(error)")
        }

        return tempURL
    }
}

/// macOS 字幕选择器
struct SubtitlePickerView: View {
    let onSelect: (URL) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        MacSubtitlePicker(onSelect: onSelect)
    }
}

struct MacSubtitlePicker: View {
    let onSelect: (URL) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack {
            Text("选择字幕文件")
                .font(.headline)
                .padding()

            Button("打开文件选择器") {
                let subtitleTypes: [UTType] = [
                    UTType(filenameExtension: "srt") ?? .plainText,
                    UTType(filenameExtension: "ass") ?? .plainText,
                    UTType(filenameExtension: "ssa") ?? .plainText
                ]

                let panel = NSOpenPanel()
                panel.allowsMultipleSelection = false
                panel.canChooseDirectories = false
                panel.canChooseFiles = true
                panel.allowedContentTypes = subtitleTypes

                if panel.runModal() == .OK, let url = panel.url {
                    let ext = url.pathExtension.lowercased()
                    guard ["srt", "ass", "ssa"].contains(ext) else { return }

                    let tempURL = copyToTemp(url: url)
                    onSelect(tempURL)
                    dismiss()
                }
            }
            .padding()

            Button("取消") {
                dismiss()
            }
            .padding()
        }
        .frame(width: 300, height: 200)
    }

    private func copyToTemp(url: URL) -> URL {
        let originalFileName = url.lastPathComponent
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(originalFileName)

        do {
            if FileManager.default.fileExists(atPath: tempURL.path) {
                try FileManager.default.removeItem(at: tempURL)
            }
            try FileManager.default.copyItem(at: url, to: tempURL)
        } catch {
            print("Failed to copy subtitle file: \(error)")
        }

        return tempURL
    }
}

#else

// MARK: - iOS Document Picker

enum DocumentPickerMode {
    case open
    case importFile
}

struct DocumentPickerView: UIViewControllerRepresentable {
    let supportedTypes: [UTType]
    let pickerMode: DocumentPickerMode
    let onPick: ([URL]) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: supportedTypes)
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: ([URL]) -> Void

        init(onPick: @escaping ([URL]) -> Void) {
            self.onPick = onPick
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }

            guard url.startAccessingSecurityScopedResource() else { return }

            let originalFileName = url.lastPathComponent
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(originalFileName)

            do {
                if FileManager.default.fileExists(atPath: tempURL.path) {
                    try FileManager.default.removeItem(at: tempURL)
                }
                try FileManager.default.copyItem(at: url, to: tempURL)
                onPick([tempURL])
            } catch {
                print("Failed to copy file: \(error)")
            }

            url.stopAccessingSecurityScopedResource()
        }
    }
}

// MARK: - Subtitle Picker
struct SubtitlePickerView: UIViewControllerRepresentable {
    let onSelect: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let subtitleTypes: [UTType] = [
            UTType(filenameExtension: "srt") ?? .plainText,
            UTType(filenameExtension: "ass") ?? .plainText,
            UTType(filenameExtension: "ssa") ?? .plainText
        ]

        let picker = UIDocumentPickerViewController(forOpeningContentTypes: subtitleTypes)
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelect: onSelect)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onSelect: (URL) -> Void

        init(onSelect: @escaping (URL) -> Void) {
            self.onSelect = onSelect
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }

            let ext = url.pathExtension.lowercased()
            guard ["srt", "ass", "ssa"].contains(ext) else { return }

            guard url.startAccessingSecurityScopedResource() else { return }

            let originalFileName = url.lastPathComponent
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(originalFileName)

            do {
                if FileManager.default.fileExists(atPath: tempURL.path) {
                    try FileManager.default.removeItem(at: tempURL)
                }
                try FileManager.default.copyItem(at: url, to: tempURL)
                onSelect(tempURL)
            } catch {
                print("Failed to copy subtitle file: \(error)")
            }

            url.stopAccessingSecurityScopedResource()
        }
    }
}

#endif
