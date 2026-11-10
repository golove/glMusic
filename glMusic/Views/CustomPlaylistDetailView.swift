//
//  CustomPlaylistDetailView.swift
//  glMusic
//
//  Created by go love on 11/10/26.
//

import SwiftUI
import NeteaseCloudMusicAPI

struct CustomPlaylistDetailView: View {
    let playlistId: String
    var onBack: (() -> Void)? = {
        print("press back")
    }
    var onDelete: (() -> Void)?

    @Environment(PlayerManager.self) private var player
    @Environment(ThemeManager.self) private var themeManager
    private var playlistManager = CustomPlaylistManager.shared

    @State private var showRenameSheet = false
    @State private var newName = ""
    @State private var newDesc = ""
    @State private var showDeleteConfirm = false

    private var playlist: CustomPlaylist? {
        playlistManager.playlist(withId: playlistId)
    }

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if let pl = playlist {
                        if pl.songs.isEmpty {
                            emptyStateView
                        } else {
                            LazyVStack(spacing: 0) {
                                ForEach(Array(pl.songs.enumerated()), id: \.element.id) { idx, song in
                                    UnifiedSongRow(song: song, index: idx + 1, allSongs: pl.songs)
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

                                            Button(role: .destructive) {
                                                playlistManager.removeSong(songId: song.id, fromPlaylistId: playlistId)
                                            } label: {
                                                Label("从歌单中移除".localized, systemImage: "trash")
                                            }

                                            Divider()

                                            if DownloadManager.shared.isDownloaded(song.id) {
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
                                        }
                                }
                            }
                        }
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "music.note")
                                .font(.system(size: 36))
                                .foregroundStyle(.tertiary)
                            Text("歌单不存在或已删除".localized)
                                .font(.headline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 200)
                    }

                    Spacer(minLength: 120)
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                // 顶部常驻固定导航栏 (不随下方列表滚动，与推荐歌单样式完全一致)
                if let onBack = onBack {
                    VStack {
                        HStack(alignment: .top) {
                            topPinnedBar(onBack: onBack)

                            if let pl = playlist {
                                headerSection(pl)
                                    .padding(.top, 12)
                            }
                        }

                        // Column headers
                        if let pl = playlist, !pl.songs.isEmpty {
                            HStack(spacing: 0) {
                                Text("#").frame(width: 36, alignment: .center)
                                Text("标题".localized).frame(maxWidth: .infinity, alignment: .leading)
                                Text("艺人".localized).frame(width: 160, alignment: .leading)
                                Text("专辑".localized).frame(width: 160, alignment: .leading)
                                Image(systemName: "clock").frame(width: 60, alignment: .trailing)
                            }
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 6)

                            Divider()
                                .padding(.horizontal, 24)
                                .opacity(0.4)
                        }
                    }
                    .background(.ultraThinMaterial)
                    .zIndex(1)
                }
            }
        }
        .padding(.top, 6)
        .sheet(isPresented: $showRenameSheet) {
            renameSheet
        }
        .confirmationDialog(
            "确认删除该自建歌单？".localized,
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("删除歌单".localized, role: .destructive) {
                playlistManager.deletePlaylist(id: playlistId)
                onDelete?()
            }
            Button("取消".localized, role: .cancel) {}
        } message: {
            Text("歌单删除后不可恢复，但不会删除已下载的本地歌曲文件。".localized)
        }
    }

    // MARK: - Top Pinned Bar

    private func topPinnedBar(onBack: @escaping () -> Void) -> some View {
        Button(action: onBack) {
            Image(systemName: "chevron.left")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(themeManager.accentColor)
                .padding(8)
                .background(themeManager.tintColor, in: Circle())
        }
        .padding(.horizontal, 6)
        .buttonStyle(.plain)
        .keyboardShortcut("[", modifiers: [.command])
        .help("返回 (⌘[)".localized)
    }

    // MARK: - Header Section

    private func headerSection(_ pl: CustomPlaylist) -> some View {
        HStack(alignment: .top) {
            // 封面 (与推荐歌单 180x180 规格保持一致)
            ZStack {
                if let cover = pl.coverUrl, !cover.isEmpty {
                    AsyncImage(url: URL(string: cover)) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable().aspectRatio(contentMode: .fill)
                        default:
                            coverPlaceholder
                        }
                    }
                } else {
                    coverPlaceholder
                }
            }
            .frame(width: 180, height: 180)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.15), radius: 10, y: 5)

            // 信息详情
            VStack(alignment: .leading, spacing: 8) {
                Text("自建歌单".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Text(pl.name)
                    .font(.title.bold())
                    .lineLimit(2)

                if !pl.description.isEmpty {
                    Text(pl.description)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }

                Text(String(format: "%d 首歌曲".localized, pl.trackCount))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                // 操作按钮组 (与推荐歌单统一使用 PlaybackActionBar，并附加编辑与删除胶囊按钮)
                HStack(spacing: 12) {
                    if !pl.songs.isEmpty {
                        PlaybackActionBar(songs: pl.songs, downloadHelpText: "下载此歌单中的全部歌曲到本地".localized)
                    } else {
                        Spacer()
                    }

                    Button {
                        newName = pl.name
                        newDesc = pl.description
                        showRenameSheet = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "pencil")
                            Text("编辑".localized)
                        }
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.quaternary, in: Capsule())
                        .foregroundStyle(.primary)
                    }
                    .buttonStyle(.plain)
                    .help("编辑歌单名称与描述".localized)

                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                            .foregroundStyle(.red.opacity(0.85))
                            .frame(width: 32, height: 32)
                            .background(Color.red.opacity(0.1), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .help("删除歌单".localized)
                }
                .padding(.bottom, 20)
            }
            .padding(.top, 8)
            .frame(height: 200)
        }
    }

    private var coverPlaceholder: some View {
        LinearGradient(
            colors: [themeManager.accentColor.opacity(0.75), themeManager.accentColor.opacity(0.35)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            Image(systemName: "music.note.list")
                .font(.system(size: 46))
                .foregroundStyle(.white.opacity(0.9))
        )
    }

    // MARK: - 空状态提示

    private var emptyStateView: some View {
        VStack(spacing: 14) {
            Image(systemName: "music.note")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)

            Text("歌单暂无歌曲".localized)
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("在任意歌曲右键选择「添加到歌单」即可收藏至此".localized)
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
        .padding(.top, 40)
    }

    // MARK: - Rename Sheet

    private var renameSheet: some View {
        VStack(spacing: 16) {
            Text("编辑歌单信息".localized)
                .font(.headline)

            VStack(alignment: .leading, spacing: 6) {
                Text("歌单名称".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("歌单名称".localized, text: $newName)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("歌单描述 (可选)".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("简短描述该歌单".localized, text: $newDesc)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                Button("取消".localized) {
                    showRenameSheet = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("保存".localized) {
                    playlistManager.renamePlaylist(id: playlistId, newName: newName, newDescription: newDesc)
                    showRenameSheet = false
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .tint(themeManager.accentColor)
                .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.top, 8)
        }
        .padding(20)
        .frame(width: 340)
    }
}
