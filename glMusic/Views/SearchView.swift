//
//  SearchView.swift
//  glMusic
//
//  Created by go love on 10/7/26.
//

import SwiftUI

// MARK: - Search History Manager

@MainActor
@Observable
final class SearchHistoryManager {
    static let shared = SearchHistoryManager()

    var history: [String] = []
    private let key = "search_history_items"
    private let maxCount = 20

    private init() {
        history = UserDefaults.standard.stringArray(forKey: key) ?? []
    }

    func add(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        history.removeAll { $0.caseInsensitiveCompare(trimmed) == .orderedSame }
        history.insert(trimmed, at: 0)
        if history.count > maxCount {
            history = Array(history.prefix(maxCount))
        }
        UserDefaults.standard.set(history, forKey: key)
    }

    func remove(_ query: String) {
        history.removeAll { $0 == query }
        UserDefaults.standard.set(history, forKey: key)
    }

    func clear() {
        history.removeAll()
        UserDefaults.standard.removeObject(forKey: key)
    }
}

// MARK: - Search View

struct SearchView: View {
    @Environment(PlayerManager.self) private var player
    @Environment(ThemeManager.self) private var themeManager
    @State private var searchText = ""
    @State private var results: [APISong] = []
    @State private var hotSearches: [HotSearchItem] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?
    @State private var historyManager = SearchHistoryManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Title
            Text("搜索".localized)
                .font(.largeTitle.bold())
                .padding(.horizontal, 24)
                .padding(.top, 12)

            // Search field
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("搜索歌曲、艺人、专辑".localized, text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .onSubmit { performSearch() }
                if isSearching {
                    ProgressView().controlSize(.small)
                }
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        results = []
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 24)
            .onChange(of: searchText) {
                searchTask?.cancel()
                searchTask = Task {
                    try? await Task.sleep(for: .milliseconds(400))
                    if !Task.isCancelled && !searchText.trimmingCharacters(in: .whitespaces).isEmpty {
                        performSearch()
                    }
                }
            }

            if searchText.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // 1. 最近搜索历史 (Search History)
                        if !historyManager.history.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text("最近搜索".localized)
                                        .font(.title3.bold())

                                    Spacer()

                                    Button {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            historyManager.clear()
                                        }
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: "trash")
                                                .font(.system(size: 11))
                                            Text("清空历史".localized)
                                                .font(.system(size: 11, weight: .medium))
                                        }
                                        .foregroundStyle(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }

                                FlowLayout(spacing: 8) {
                                    ForEach(historyManager.history, id: \.self) { item in
                                        HStack(spacing: 5) {
                                            Button {
                                                searchText = item
                                                performSearch()
                                            } label: {
                                                Text(item)
                                                    .font(.system(size: 13))
                                                    .foregroundStyle(.primary)
                                            }
                                            .buttonStyle(.plain)

                                            Button {
                                                withAnimation(.easeInOut(duration: 0.15)) {
                                                    historyManager.remove(item)
                                                }
                                            } label: {
                                                Image(systemName: "xmark")
                                                    .font(.system(size: 9, weight: .bold))
                                                    .foregroundStyle(.tertiary)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                        .padding(.leading, 12)
                                        .padding(.trailing, 8)
                                        .padding(.vertical, 6)
                                        .background(.quaternary, in: Capsule())
                                    }
                                }
                            }
                        }

                        // 2. 热门搜索 (Hot Searches)
                        if !hotSearches.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("热门搜索".localized)
                                    .font(.title3.bold())

                                FlowLayout(spacing: 8) {
                                    ForEach(Array(hotSearches.prefix(15).enumerated()), id: \.element.id) { idx, item in
                                        Button {
                                            searchText = item.searchWord
                                            performSearch()
                                        } label: {
                                            HStack(spacing: 6) {
                                                Text("\(idx + 1)")
                                                    .font(.system(size: 11, weight: .bold).monospacedDigit())
                                                    .foregroundStyle(idx < 3 ? themeManager.accentColor : Color.secondary)

                                                Text(item.searchWord)
                                                    .font(.system(size: 13))
                                            }
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 7)
                                            .background(.quaternary, in: Capsule())
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            } else if results.isEmpty && !isSearching {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 36))
                        .foregroundStyle(.tertiary)
                    Text("没有找到结果".localized)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                // Search results
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(results.enumerated()), id: \.element.id) { idx, song in
                            UnifiedSongRow(song: song, index: idx + 1, allSongs: results)
                        }
                    }
                    .padding(.bottom, 80)
                }
            }

            Spacer()
        }
        .task { await loadHotSearches() }
    }

    private func performSearch() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }

        // 保存到搜索历史
        historyManager.add(query)

        Task {
            isSearching = true
            defer { isSearching = false }
            do {
                results = try await NetworkManager.shared.search(keywords: query)
            } catch {
                print("搜索失败: \(error)")
            }
        }
    }

    private func loadHotSearches() async {
        do {
            hotSearches = try await NetworkManager.shared.hotSearch()
        } catch {
            print("热搜加载失败: \(error)")
        }
    }
}

// MARK: - Flow Layout (for tags)

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(subviews: subviews, width: proposal.width ?? .infinity)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(subviews: subviews, width: bounds.width)
        for (index, frame) in result.frames.enumerated() {
            guard subviews.indices.contains(index) else { continue }
            subviews[index].place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                                  proposal: ProposedViewSize(frame.size))
        }
    }

    private func layout(subviews: Subviews, width: CGFloat) -> (size: CGSize, frames: [CGRect]) {
        var frames: [CGRect] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > width && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (CGSize(width: width, height: y + rowHeight), frames)
    }
}

#Preview {
    SearchView()
        .environment(PlayerManager())
        .environment(ThemeManager.shared)
}
