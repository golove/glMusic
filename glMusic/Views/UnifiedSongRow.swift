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

    @Environment(PlayerManager.self) private var player
    @Environment(ThemeManager.self) private var themeManager
    @State private var isHovered: Bool = false

    var body: some View {
        let isCurrent = player.currentSong?.id == song.id

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
                    Group {
                        if let localURL = DownloadManager.shared.localCoverURL(for: song.id),
                           let img = NSImage(contentsOf: localURL) {
                            Image(nsImage: img)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else {
                            AsyncImage(url: URL(string: song.coverUrl ?? "")) { phase in
                                switch phase {
                                case .success(let img):
                                    img.resizable().aspectRatio(contentMode: .fill)
                                default:
                                    Rectangle().fill(.quaternary)
                                        .overlay(
                                            Image(systemName: "music.note")
                                                .font(.system(size: 12))
                                                .foregroundStyle(.tertiary)
                                        )
                                }
                            }
                        }
                    }
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }

                HStack(spacing: 8) {
                    Text(song.name)
                        .font(.system(size: 13, weight: isCurrent ? .semibold : .regular))
                        .foregroundStyle(isCurrent ? themeManager.accentColor : .primary)
                        .lineLimit(1)

                    if isHovered || player.isLiked(song.id) || DownloadManager.shared.isDownloaded(song.id) || DownloadManager.shared.isDownloading(song.id) {
                        Button {
                            player.toggleLike(for: song)
                        } label: {
                            Image(systemName: player.isLiked(song.id) ? "heart.fill" : "heart")
                                .font(.system(size: 11))
                                .foregroundStyle(player.isLiked(song.id) ? themeManager.accentColor : .secondary)
                        }
                        .buttonStyle(.plain)

                        DownloadButton(song: song, iconSize: 11)
                    }
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
        .background(
            isHovered
                ? Color.primary.opacity(0.04)
                : (isCurrent ? themeManager.accentColor.opacity(0.06) : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
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

            Divider()

            if DownloadManager.shared.isDownloaded(song.id) {
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
