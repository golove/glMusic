//
//  SearchView.swift
//  glMusic
//
//  Created by go love on 10/7/26.
//

import SwiftUI

struct SearchView: View {
    @Environment(PlayerManager.self) private var player
    @State private var searchText = ""
    @State private var results: [APISong] = []
    @State private var hotSearches: [HotSearchItem] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?

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
                    Button { searchText = ""; results = [] } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
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
                    if !Task.isCancelled && !searchText.isEmpty {
                        performSearch()
                    }
                }
            }

            if searchText.isEmpty {
                // Hot searches
                if !hotSearches.isEmpty {
                    Text("热门搜索".localized)
                        .font(.title3.bold())
                        .padding(.horizontal, 24)

                    FlowLayout(spacing: 8) {
                        ForEach(hotSearches.prefix(15)) { item in
                            Button {
                                searchText = item.searchWord
                                performSearch()
                            } label: {
                                Text(item.searchWord)
                                    .font(.system(size: 13))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 7)
                                    .background(.quaternary, in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 24)
                }
            } else if results.isEmpty && !isSearching {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 36)).foregroundStyle(.tertiary)
                    Text("没有找到结果".localized)
                        .font(.headline).foregroundStyle(.secondary)
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
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let query = searchText
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

// MARK: - Flow Layout (for hot search tags)

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(subviews: subviews, width: proposal.width ?? .infinity)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(subviews: subviews, width: bounds.width)
        for (index, frame) in result.frames.enumerated() {
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
