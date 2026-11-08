//
//  PlaylistSquareView.swift
//  glMusic
//
//  Created by go love on 11/8/26.
//

import SwiftUI

/// 歌单广场视图（只显示官方歌单）
struct PlaylistSquareView: View {
    @Binding var selection: String?
    @Environment(PlayerManager.self) private var player
    @Environment(ThemeManager.self) private var themeManager
    @Environment(LanguageManager.self) private var languageManager

    // 分类列表
    private let categories = [
        "精选", "华语", "流行", "摇滚", "民谣", "电子",
        "欧美", "说唱", "ACG", "轻音乐", "影视原声",
        "古典", "爵士", "R&B/Soul", "古风", "怀旧"
    ]

    @State private var selectedCategory: String = "精选"
    @State private var playlists: [APIPlaylist] = []
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var hasMore = true
    @State private var offset = 0
    @State private var searchText = ""
    @State private var errorMessage: String? = nil

    private let pageSize = 60
    private let columns = [GridItem(.adaptive(minimum: 170, maximum: 220), spacing: 22)]

    init(selection: Binding<String?>? = nil) {
        self._selection = selection ?? .constant("playlistSquare")
    }

    private var filteredPlaylists: [APIPlaylist] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return playlists }
        return playlists.filter { pl in
            pl.name.lowercased().contains(query) ||
            (pl.creator?.nickname?.lowercased().contains(query) ?? false) ||
            (pl.description?.lowercased().contains(query) ?? false)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
            

                // MARK: - Content Body
                if isLoading && playlists.isEmpty {
                    loadingView
                } else if let error = errorMessage, playlists.isEmpty {
                    errorView(error)
                } else if filteredPlaylists.isEmpty {
                    emptyView
                } else {
                    playlistGrid
                }

                Spacer(minLength: 120)
            }
            .padding(.horizontal, 28)
            .padding(.top, 18)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                // MARK: - Header
                headerSection

                // MARK: - Category Filter Bar
                categoryBar

                Divider()
                    .opacity(0.4)
            }
            .padding(.horizontal, 28)
            .padding(.top, 14)
            .padding(.bottom, 6)
            .background(.ultraThinMaterial)
        }
        .task(id: selectedCategory) {
            await loadPlaylists(refresh: true)
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text("歌单广场".localized)
                        .font(.system(size: 32, weight: .bold))

                    // 官方专属标签
                    HStack(spacing: 3) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 11))
                        Text("官方甄选".localized)
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(themeManager.accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(themeManager.accentColor.opacity(0.12))
                    .clipShape(Capsule())
                }

                Text("网易云音乐官方精选优质歌单，沉浸纯粹音乐世界".localized)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // 搜索框与刷新按钮
            HStack(spacing: 12) {
                searchField

                Button {
                    Task { await loadPlaylists(refresh: true, force: true) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(8)
                        .background(.quaternary.opacity(0.5))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("刷新".localized)
            }
        }
    }

    // MARK: - Search Field

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)

            TextField("搜索歌单...".localized, text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 12))

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(width: 200)
        .background(.quaternary.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Category Bar

    private var categoryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(categories, id: \.self) { cat in
                    let isSelected = (selectedCategory == cat)
                    Button {
                        if selectedCategory != cat {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedCategory = cat
                            }
                        }
                    } label: {
                        Text(cat.localized)
                            .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                            .foregroundStyle(isSelected ? .white : .primary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(
                                Capsule()
                                    .fill(isSelected ? themeManager.accentColor : Color.primary.opacity(0.06))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Playlist Grid

    private var playlistGrid: some View {
        VStack(spacing: 24) {
            LazyVGrid(columns: columns, spacing: 22) {
                ForEach(filteredPlaylists) { pl in
                    OfficialPlaylistCard(playlist: pl) {
                        selection = "playlist_\(pl.id)"
                    }
                }
            }

            // 加载更多区域
            if hasMore && searchText.isEmpty {
                Button {
                    Task { await loadMorePlaylists() }
                } label: {
                    HStack(spacing: 6) {
                        if isLoadingMore {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "arrow.down.circle")
                        }
                        Text(isLoadingMore ? "正在加载...".localized : "加载更多歌单".localized)
                            .font(.system(size: 13, weight: .medium))
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(.quaternary.opacity(0.6))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(isLoadingMore)
                .padding(.top, 12)
            }
        }
    }

    // MARK: - States

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.large)
            Text("正在加载官方歌单...".localized)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 38))
                .foregroundStyle(.secondary)

            Text("加载失败".localized)
                .font(.headline)

            Text(error)
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("重试".localized) {
                Task { await loadPlaylists(refresh: true, force: true) }
            }
            .buttonStyle(.borderedProminent)
            .tint(themeManager.accentColor)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "music.note.list")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)

            Text("未找到相关官方歌单".localized)
                .font(.headline)
                .foregroundStyle(.secondary)

            if !searchText.isEmpty {
                Button("清空搜索".localized) {
                    searchText = ""
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }

    // MARK: - Data Loading

    private func loadPlaylists(refresh: Bool = false, force: Bool = false) async {
        if refresh {
            isLoading = true
            offset = 0
            errorMessage = nil
        }

        do {
            let list = try await NetworkManager.shared.officialPlaylists(
                cat: selectedCategory,
                limit: pageSize,
                offset: 0,
                forceRefresh: force
            )

            // 再次确保只展示官方歌单
            let filtered = list.filter { $0.isOfficial }
            self.playlists = filtered
            self.offset = filtered.count
            self.hasMore = list.count >= pageSize
            self.isLoading = false
        } catch {
            self.errorMessage = error.localizedDescription
            self.isLoading = false
        }
    }

    private func loadMorePlaylists() async {
        guard !isLoadingMore && hasMore else { return }
        isLoadingMore = true

        do {
            let nextBatch = try await NetworkManager.shared.officialPlaylists(
                cat: selectedCategory,
                limit: pageSize,
                offset: offset,
                forceRefresh: false
            )

            let filtered = nextBatch.filter { $0.isOfficial }
            let existingIds = Set(self.playlists.map(\.id))
            let newItems = filtered.filter { !existingIds.contains($0.id) }

            self.playlists.append(contentsOf: newItems)
            self.offset += nextBatch.count
            self.hasMore = nextBatch.count >= pageSize
        } catch {
            print("loadMorePlaylists error: \(error)")
        }

        isLoadingMore = false
    }
}

// MARK: - Official Playlist Card

struct OfficialPlaylistCard: View {
    let playlist: APIPlaylist
    var onSelect: (() -> Void)? = nil

    @Environment(PlayerManager.self) private var player
    @Environment(ThemeManager.self) private var themeManager
    @State private var isHovering = false
    @State private var isPlayHovering = false
    @State private var isLoadingTracks = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // MARK: - Cover with Overlay
            ZStack(alignment: .bottomTrailing) {
                // 封面点击
                Button {
                    onSelect?()
                } label: {
                    AsyncImage(url: URL(string: playlist.displayCover ?? "")) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        default:
                            Rectangle()
                                .fill(.quaternary)
                                .overlay(
                                    Image(systemName: "music.note.list")
                                        .font(.title2)
                                        .foregroundStyle(.tertiary)
                                )
                        }
                    }
                    .frame(minWidth: 160, maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)

                // 官方角标 (左上角)
                VStack {
                    HStack {
                        HStack(spacing: 3) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 9))
                            Text("官方".localized)
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(themeManager.accentColor.opacity(0.92))
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.3), radius: 3, y: 1)

                        Spacer()
                    }
                    Spacer()
                }
                .padding(8)
                .allowsHitTesting(false)

                // 播放量角标 (左下角)
                if let count = playlist.playCount {
                    VStack {
                        Spacer()
                        HStack {
                            HStack(spacing: 3) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 8))
                                Text(formatCount(count))
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(.black.opacity(0.55))
                            .clipShape(Capsule())

                            Spacer()
                        }
                    }
                    .padding(8)
                    .allowsHitTesting(false)
                }

                // 悬停快捷播放按钮 (右下角)
                if isHovering {
                    Button {
                        loadAndPlay()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(themeManager.accentColor)
                                .frame(width: 38, height: 38)
                                .shadow(color: .black.opacity(0.35), radius: 6, y: 3)

                            if isLoadingTracks {
                                ProgressView()
                                    .controlSize(.small)
                                    .tint(.white)
                            } else {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.white)
                                    .offset(x: 1.5)
                            }
                        }
                        .scaleEffect(isPlayHovering ? 1.08 : 1.0)
                    }
                    .buttonStyle(.plain)
                    .onHover { h in
                        withAnimation(.easeInOut(duration: 0.1)) {
                            isPlayHovering = h
                        }
                    }
                    .padding(8)
                    .transition(.opacity.combined(with: .scale(scale: 0.85)))
                }
            }
            .scaleEffect(isHovering ? 1.02 : 1.0)
            .shadow(color: .black.opacity(isHovering ? 0.18 : 0.08), radius: isHovering ? 10 : 5, y: 4)
            .animation(.easeInOut(duration: 0.2), value: isHovering)
            .onHover { h in
                isHovering = h
            }

            // MARK: - Title & Creator
            Button {
                onSelect?()
            } label: {
                VStack(alignment: .leading, spacing: 3) {
                    Text(playlist.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(themeManager.accentColor)

                        Text(playlist.creator?.nickname ?? "网易云音乐".localized)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
    }

    private func loadAndPlay() {
        guard !isLoadingTracks else { return }
        isLoadingTracks = true
        Task {
            do {
                let songs = try await NetworkManager.shared.playlistTracks(id: playlist.id, limit: 50)
                if !songs.isEmpty {
                    player.playAll(songs)
                }
            } catch {
                print("加载歌单失败: \(error)")
            }
            isLoadingTracks = false
        }
    }

    private func formatCount(_ count: Int) -> String {
        if count >= 100_000_000 {
            return String(format: "%.1f亿", Double(count) / 100_000_000)
        } else if count >= 10_000 {
            return String(format: "%.1f万", Double(count) / 10_000)
        } else {
            return "\(count)"
        }
    }
}
