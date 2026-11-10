//
//  UnifiedSongRow.swift
//  glMusic
//
//  Created by go love on 11/2/26.
//

import SwiftUI

/// Apple Music 风格通用歌曲行组件，统一聚合播放、悬停、喜欢、下载、右键操作菜单
struct UnifiedSongRow: View {
    let song: APISong
    var index: Int? = nil
    var allSongs: [APISong]? = nil
    var showCover: Bool = true
    var showArtist: Bool = true
    var showAlbum: Bool = true
    var artistWidth: CGFloat = 160
    var albumWidth: CGFloat = 160
    var horizontalPadding: CGFloat = 24
    var verticalPadding: CGFloat = 6
    var onTap: (() -> Void)? = nil
    var onDeleteFromPlaylist: (() -> Void)? = nil

    @Environment(PlayerManager.self) private var player
    @Environment(ThemeManager.self) private var themeManager
    @State private var isHovered: Bool = false
    @State private var hoverDebounceTask: Task<Void, Never>?

    var body: some View {
        let isCurrent = player.currentSong?.id == song.id
        let isLiked = player.isLiked(song.id)
        let isDownloaded = DownloadManager.shared.downloadedSongIds.contains(song.id)
        let isDownloading = DownloadManager.shared.activeDownloads[song.id] != nil || DownloadManager.shared.isWaiting(song.id)
        let showActions = isHovered || isLiked || isDownloaded || isDownloading

        HStack(spacing: 0) {
            // MARK: - 序号 / 播放指示器
            if let idx = index {
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
                        Text("\(idx)")
                            .font(.system(size: 12).monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 36)
            }

            // MARK: - 封面 + 歌曲标题 + 操作徽标
            HStack(spacing: 10) {
                if showCover {
                    SongCoverThumbnailView(songId: song.id, coverUrl: song.coverUrl, size: 36)
                }

                HStack(spacing: 8) {
                    Text(song.name)
                        .font(.system(size: 13, weight: isCurrent ? .semibold : .regular))
                        .foregroundStyle(isCurrent ? themeManager.accentColor : .primary)
                        .lineLimit(1)

                    // 保持固定布局占位，仅透明度切换，避免滚动过程中的文本重排与布局抖动 (Layout Thrashing)
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

            // MARK: - 歌手名
            if showArtist {
                Text(song.displayArtist)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(width: artistWidth, alignment: .leading)
            }

            // MARK: - 专辑名
            if showAlbum {
                Text(song.displayAlbum)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(width: albumWidth, alignment: .leading)
            }

            // MARK: - 时长
            Text(song.durationText)
                .font(.system(size: 13).monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .trailing)
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .frame(height: 48)
        .background(
            isHovered
                ? Color.primary.opacity(0.04)
                : (isCurrent ? themeManager.accentColor.opacity(0.06) : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            hoverDebounceTask?.cancel()
            if hovering {
                // 滚动防抖抑制：当用户连续滑行滚动时，行掠过光标不足 80ms 则完全不触发悬停状态变迁
                hoverDebounceTask = Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 80_000_000) // 80ms
                    guard !Task.isCancelled else { return }
                    isHovered = true
                }
            } else {
                isHovered = false
            }
        }
        .onTapGesture {
            if let customTap = onTap {
                customTap()
            } else if let songs = allSongs, let idx = index, idx - 1 >= 0, idx - 1 < songs.count {
                player.playAll(songs, from: idx - 1)
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

            if let onDelete = onDeleteFromPlaylist {
                Divider()
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("从歌单中移除".localized, systemImage: "trash")
                }
            }

            Divider()

            if DownloadManager.shared.downloadedSongIds.contains(song.id) {
                Button {
                    DownloadManager.shared.revealInFinder(song.id)
                } label: {
                    Label("在访达中显示".localized, systemImage: "folder")
                }

                Button(role: .destructive) {
                    DownloadManager.shared.deleteDownload(song.id)
                } label: {
                    Label("删除已下载文件".localized, systemImage: "trash")
                }
            } else {
                Button {
                    DownloadManager.shared.downloadSong(song)
                } label: {
                    Label("下载歌曲".localized, systemImage: "arrow.down.circle")
                }
            }

            Divider()

            Button {
                player.toggleLike(for: song)
            } label: {
                Label((player.isLiked(song.id) ? "取消喜欢" : "喜欢这首歌").localized,
                      systemImage: player.isLiked(song.id) ? "heart.slash" : "heart")
            }
        }
    }
}
