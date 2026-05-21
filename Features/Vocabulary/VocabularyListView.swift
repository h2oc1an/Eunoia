import SwiftUI
import Combine

struct VocabularyListView: View {
    @State private var words: [VocabularyEntry] = []
    @State private var searchText: String = ""
    @State private var showingAddWord: Bool = false
    @State private var selectedWord: VocabularyEntry?
    @State private var searchCancellable: AnyCancellable?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 标题栏
                HStack {
                    Text("生词本")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Color(hex: "1D1D1F"))

                    Spacer()

                    Button(action: { showingAddWord = true }) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .semibold))
                            Text("添加单词")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color(hex: "007AFF"))
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }

                // 搜索框
                searchBar

                // 单词列表
                if words.isEmpty {
                    emptyState
                } else {
                    wordList
                }
            }
            .padding(32)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(hex: "F5F5F7"))
        .sheet(isPresented: $showingAddWord) {
            AddWordView(onSave: { loadWords() })
        }
        .sheet(item: $selectedWord) { entry in
            WordDetailView(entry: entry, onUpdate: { loadWords() })
        }
        .onAppear {
            loadWords()
        }
        .onChange(of: searchText) { newValue in
            performSearchDebounced(query: newValue)
        }
    }

    // MARK: - 搜索栏
    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16))
                .foregroundColor(Color(hex: "8E8E93"))

            TextField("搜索单词", text: $searchText)
                .font(.system(size: 15))
                .textFieldStyle(.plain)

            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(Color(hex: "C7C7CC"))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(hex: "E5E5EA"), lineWidth: 1)
        )
    }

    // MARK: - 单词列表
    private var wordList: some View {
        VStack(spacing: 12) {
            ForEach(words) { entry in
                WordCardView(entry: entry)
                    .onTapGesture {
                        selectedWord = entry
                    }
                    .contextMenu {
                        Button(role: .destructive) {
                            deleteWord(entry)
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    }
            }
        }
    }

    // MARK: - 空状态
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "book")
                .font(.system(size: 50))
                .foregroundColor(Color(hex: "C7C7CC"))

            Text(searchText.isEmpty ? "还没有单词" : "未找到匹配单词")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color(hex: "8E8E93"))

            if searchText.isEmpty {
                Text("点击右上角添加单词开始学习")
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "C7C7CC"))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
    }

    // MARK: - Actions

    private func loadWords() {
        do {
            words = try VocabularyService.shared.getAllWords()
        } catch {
            print("Failed to load words: \(error)")
        }
    }

    private func performSearchDebounced(query: String) {
        searchCancellable?.cancel()

        if query.isEmpty {
            loadWords()
            return
        }

        searchCancellable = Just(query)
            .delay(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [self] debouncedQuery in
                do {
                    words = try VocabularyService.shared.search(debouncedQuery)
                } catch {
                    print("Failed to search words: \(error)")
                }
            }
    }

    private func deleteWord(_ entry: VocabularyEntry) {
        do {
            try VocabularyService.shared.deleteWord(byId: entry.id)
            loadWords()
        } catch {
            print("Failed to delete word: \(error)")
        }
    }
}

// MARK: - 单词卡片
private struct WordCardView: View {
    let entry: VocabularyEntry

    var body: some View {
        HStack(spacing: 16) {
            // 左侧：单词 + 标签
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(entry.word)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(Color(hex: "1D1D1F"))

                    if entry.nextReviewDate <= Date() {
                        Text("待复习")
                            .font(.system(size: 11, weight: .medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color(hex: "FFF3E0"))
                            .foregroundColor(Color(hex: "FF9500"))
                            .cornerRadius(4)
                    }
                }

                if let meaning = entry.meaning, !meaning.isEmpty {
                    Text(meaning)
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "6E6E73"))
                        .lineLimit(1)
                }
            }

            Spacer()

            // 右侧：复习信息
            VStack(alignment: .trailing, spacing: 4) {
                Text("复习 \(entry.repetitions) 次")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "8E8E93"))

                Text(formatDate(entry.nextReviewDate))
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "C7C7CC"))
            }
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(16)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    VocabularyListView()
}
