//
//  HistoryView.swift
//  glMusic
//
//  Created by go love on 11/8/26.
//

import SwiftUI

struct HistoryView: View {
    @Binding var selection: String?
    @Environment(PlayerManager.self) private var player
    @Environment(ThemeManager.self) private var themeManager
    @Environment(LanguageManager.self) private var languageManager

    @State private var historyManager = HistoryManager.shared
    @State private var searchText = ""
    @State private var showClearConfirm = false
    @State private var hoveredItemId: String? = nil

    init(selection: Binding<String?>? = nil) {
        self._selection = selection ?? .constant("history")
    }

    private var filteredItems: [PlayHistoryItem] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return historyManager.historyItems
        }
        let query = searchText.lowercased()
        return historyManager.historyItems.filter { item in
            item.song.name.lowercased().contains(query) ||
            item.song.displayArtist.lowercased().contains(query) ||
            item.song.displayAlbum.lowercased().contains(query)
        }
    }

    private var filteredSongs: [APISong] {
        filteredItems.map(\.song)
    }

    var body: some View {
        ScrollView {
            if historyManager.historyItems.isEmpty {
                emptyStateView
                    .padding(.top, 40)
            } else if filteredItems.isEmpty {
                noSearchResultView
                    .padding(.top, 40)
            } else {
                // 歌曲列表
                LazyVStack(spacing: 0) {
                    ForEach(Array(filteredItems.enumerated()), id: \.element.id) { index, item in
                        HistoryRowView(
                            item: item,
                            index: index + 1,
                            allSongs: filteredSongs,
                            onRemove: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    historyManager.remove(item: item)
                                }
                            }
                        )
                    }
                }
                .padding(.top, 4)
                .padding(.bottom, 120)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            // MARK: - Header (常驻置顶)
            VStack(alignment: .leading, spacing: 0) {
                // 第一行：标题 + 副标题 (左侧)；搜索框 + 清空按钮 (右侧)
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("播放历史".localized)
                            .font(.system(size: 30, weight: .bold))

                        if !historyManager.historyItems.isEmpty {
                            Text(String(format: "%d 首歌曲 · %@".localized, historyManager.historyItems.count, "记录您最近播放过的音乐".localized))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    // 右侧搜索框与清空按钮
                    if !historyManager.historyItems.isEmpty {
                        HStack(spacing: 12) {
                            searchBar

                            Button {
                                showClearConfirm = true
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 11))
                                    Text("清空历史".localized)
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.primary.opacity(0.04))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                            .buttonStyle(.plain)
                            .help("清空历史".localized)
                        }
                    }
                }
                .padding(.horizontal, 28)
                .padding(.top, 16)
                .padding(.bottom, 12)

                // 第二行：操作栏 (播放全部 / 随机播放) 与表头 (仅在有过滤数据时显示)
                if !filteredItems.isEmpty {
                    HStack(spacing: 10) {
                        Button {
                            player.playAll(filteredSongs, from: 0)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 11))
                                Text("播放全部".localized)
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(themeManager.accentColor, in: Capsule())
                        }
                        .buttonStyle(.plain)

                        Button {
                            player.playAll(filteredSongs.shuffled(), from: 0)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "shuffle")
                                    .font(.system(size: 11))
                                Text("随机播放".localized)
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(Color.primary.opacity(0.06), in: Capsule())
                        }
                        .buttonStyle(.plain)

                        Spacer()
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 12)

                    // 表头
                    tableHeader
                        .padding(.horizontal, 28)
                        .padding(.bottom, 6)

                    Divider()
                        .padding(.horizontal, 28)
                        .opacity(0.4)
                }
            }
            .background(.ultraThinMaterial)
        }
        .alert("清空播放历史".localized, isPresented: $showClearConfirm) {
            Button("取消".localized, role: .cancel) {}
            Button("清空".localized, role: .destructive) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    historyManager.clearAll()
                }
            }
        } message: {
            Text("确定要清空所有的播放记录吗？清空后不可恢复。".localized)
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.system(size: 11))

            TextField("搜索播放历史...".localized, text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 12))

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
        .frame(width: 200)
    }

    // MARK: - Table Header

    private var tableHeader: some View {
        HStack(spacing: 0) {
            Text("#")
                .frame(width: 36, alignment: .center)

            Text("歌曲".localized)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 10)

            Text("歌手".localized)
                .frame(width: 160, alignment: .leading)

            Text("专辑".localized)
                .frame(width: 150, alignment: .leading)

            Text("播放时间".localized)
                .frame(width: 120, alignment: .leading)

            Text("时长".localized)
                .frame(width: 60, alignment: .trailing)
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(.secondary)
    }

    // MARK: - Empty States

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 80)

            ZStack {
                Circle()
                    .fill(themeManager.accentColor.opacity(0.1))
                    .frame(width: 80, height: 80)

                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 38))
                    .foregroundStyle(themeManager.accentColor)
            }

            VStack(spacing: 6) {
                Text("暂无播放历史".localized)
                    .font(.system(size: 18, weight: .bold))

                Text("开始听歌后，播放过的歌曲将自动记录在这里".localized)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 120)
        }
        .frame(maxWidth: .infinity)
    }

    private var noSearchResultView: some View {
        VStack(spacing: 12) {
            Spacer(minLength: 80)

            Image(systemName: "magnifyingglass")
                .font(.system(size: 36))
                .foregroundStyle(.secondary.opacity(0.5))

            Text(String(format: "未找到与“%@”相关的播放记录".localized, searchText))
                .font(.system(size: 13))
                .foregroundStyle(.secondary)

            Button("清除搜索".localized) {
                searchText = ""
            }
            .buttonStyle(.plain)
            .font(.system(size: 12))
            .foregroundStyle(themeManager.accentColor)

            Spacer(minLength: 120)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - History Row View

private struct HistoryRowView: View {
    let item: PlayHistoryItem
    let index: Int
    let allSongs: [APISong]
    var onRemove: () -> Void

    @Environment(PlayerManager.self) private var player
    @Environment(ThemeManager.self) private var themeManager
    @State private var isHovered = false
    @State private var hoverDebounceTask: Task<Void, Never>?

    private var song: APISong { item.song }

    var body: some View {
        let isCurrent = player.currentSong?.id == song.id
        let isLiked = player.isLiked(song.id)
        let isDownloaded = DownloadManager.shared.downloadedSongIds.contains(song.id)
        let isDownloading = DownloadManager.shared.activeDownloads[song.id] != nil || DownloadManager.shared.isWaiting(song.id)
        let showActions = isHovered || isLiked || isDownloaded || isDownloading

        HStack(spacing: 0) {
            // 序号 / 状态指示器
            ZStack {
                if isCurrent {
                    Image(systemName: player.isPlaying ? "speaker.wave.2.fill" : "pause.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(themeManager.accentColor)
                } else if isHovered {
                    Image(systemName: "play.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.primary)
                } else {
                    Text("\(index)")
                        .font(.system(size: 12).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 36)

            // 封面 + 标题 + 操作按钮
            HStack(spacing: 10) {
                // 封面采用纯底层的 ImageIO 下采样微缩图引擎 (带 120ms 滚动节流)
                SongCoverThumbnailView(songId: song.id, coverUrl: song.coverUrl, size: 36)

                // 标题与操作
                HStack(spacing: 8) {
                    Text(song.name)
                        .font(.system(size: 13, weight: isCurrent ? .semibold : .regular))
                        .foregroundStyle(isCurrent ? themeManager.accentColor : .primary)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Button {
                            player.toggleLike(for: song)
                        } label: {
                            Image(systemName: isLiked ? "heart.fill" : "heart")
                                .font(.system(size: 11))
                                .foregroundStyle(isLiked ? themeManager.accentColor : .secondary)
                        }
                        .buttonStyle(.plain)

                        DownloadButton(song: song, iconSize: 11, hasContextMenu: false)
                    }
                    .opacity(showActions ? 1 : 0)
                    .allowsHitTesting(showActions)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // 歌手
            Text(song.displayArtist)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(width: 160, alignment: .leading)

            // 专辑
            Text(song.displayAlbum)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(width: 150, alignment: .leading)

            // 播放时间 + 播放次数提示
            HStack(spacing: 6) {
                Text(item.relativeTimeText)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)

                if item.playCount > 1 {
                    Text("\(item.playCount)x")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(themeManager.accentColor)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(themeManager.accentColor.opacity(0.12), in: Capsule())
                        .help(String(format: "已听过 %d 次".localized, item.playCount))
                }
            }
            .frame(width: 120, alignment: .leading)

            // 时长与单行删除 (常驻占位，仅透明度切换避免重排)
            HStack(spacing: 8) {
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 18, height: 18)
                        .background(Color.primary.opacity(0.06), in: Circle())
                }
                .buttonStyle(.plain)
                .help("从历史中移除".localized)
                .opacity(isHovered ? 1 : 0)
                .allowsHitTesting(isHovered)

                Text(song.durationText)
                    .font(.system(size: 13).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 44, alignment: .trailing)
            }
            .frame(width: 60, alignment: .trailing)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 6)
        .frame(height: 48) // 锁定固定 48px 行高
        .background(
            isHovered
                ? Color.primary.opacity(0.04)
                : (isCurrent ? themeManager.accentColor.opacity(0.06) : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            hoverDebounceTask?.cancel()
            if hovering {
                hoverDebounceTask = Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 80_000_000) // 80ms 防抖
                    guard !Task.isCancelled else { return }
                    isHovered = true
                }
            } else {
                isHovered = false
            }
        }
        .onTapGesture {
            if let idx = allSongs.firstIndex(where: { $0.id == song.id }) {
                player.playAll(allSongs, from: idx)
            } else {
                player.play(song)
            }
        }
        .contextMenu {
            Button {
                player.play(song)
            } label: {
                Label("立即播放".localized, systemImage: "play.fill")
            }

            Button {
                player.playNext(song)
            } label: {
                Label("下一首播放".localized, systemImage: "text.insert")
            }

            Button {
                player.addToPlaylist(song)
            } label: {
                Label("添加到播放列表".localized, systemImage: "text.badge.plus")
            }

            // MARK: - 添加到自建歌单
            AddToPlaylistMenu(song: song)

            Divider()

            Button {
                player.toggleLike(for: song)
            } label: {
                Label((player.isLiked(song.id) ? "取消喜欢" : "喜欢这首歌").localized,
                      systemImage: player.isLiked(song.id) ? "heart.slash" : "heart")
            }

            if DownloadManager.shared.downloadedSongIds.contains(song.id) {
                Button {
                    DownloadManager.shared.revealInFinder(song.id)
                } label: {
                    Label("在访达中显示".localized, systemImage: "folder")
                }
            } else {
                Button {
                    DownloadManager.shared.downloadSong(song)
                } label: {
                    Label("下载歌曲".localized, systemImage: "arrow.down.circle")
                }
            }

            Divider()

            Button(role: .destructive, action: onRemove) {
                Label("从历史中移除".localized, systemImage: "trash")
            }
        }
    }
}

#Preview {
    HistoryView()
        .frame(width: 1200)
        .environment(PlayerManager())
        .environment(ThemeManager.shared)
        .environment(LanguageManager.shared)
}
