//
//  DownloadedSongsView.swift
//  glMusic
//
//  Created by go love on 10/29/26.
//

import SwiftUI

struct DownloadedSongsView: View {
    @Environment(PlayerManager.self) private var player
    @State private var downloadManager = DownloadManager.shared
    @State private var searchText: String = ""
    @State private var hoveredSongId: Int?
    @State private var showClearConfirm: Bool = false

    private var filteredSongs: [DownloadedSong] {
        let list = downloadManager.downloadedSongs
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return list
        }
        let q = searchText.lowercased()
        return list.filter {
            $0.name.lowercased().contains(q) ||
            $0.artist.lowercased().contains(q) ||
            $0.album.lowercased().contains(q)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header Section
            headerSection
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 14)

            Divider()
                .padding(.horizontal, 24)

            // Content
            if downloadManager.downloadedSongs.isEmpty {
                emptyStateView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Table header
                tableHeaderView
                    .padding(.horizontal, 24)
                    .padding(.top, 10)
                    .padding(.bottom, 6)

                Divider()
                    .padding(.horizontal, 24)

                // Song List
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(filteredSongs.enumerated()), id: \.element.id) { idx, song in
                            downloadedSongRow(song: song, index: idx + 1)
                                .onHover { h in hoveredSongId = h ? song.id : nil }
                                .onTapGesture {
                                    playSong(song)
                                }
                        }
                    }
                    .padding(.bottom, 90)
                }
            }
        }
        .confirmationDialog(
            "确认清空所有已下载歌曲？",
            isPresented: $showClearConfirm,
            titleVisibility: .visible
        ) {
            Button("清空全部下载文件", role: .destructive) {
                downloadManager.clearAllDownloads()
            }
            Button("取消", role: .cancel) { }
        } message: {
            Text("将从本地磁盘删除全部已下载的音频、封面和歌词文件。")
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(.pink)
                    Text("已下载")
                        .font(.largeTitle.bold())
                }

                Spacer()

                // Search field
                if !downloadManager.downloadedSongs.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        TextField("在已下载歌曲中搜索...", text: $searchText)
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
                    .padding(.vertical, 5)
                    .frame(width: 220)
                    .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
                }
            }

            if !downloadManager.downloadedSongs.isEmpty {
                HStack(spacing: 12) {
                    // Play all
                    Button {
                        let apiSongs = filteredSongs.map(\.asAPISong)
                        player.playAll(apiSongs)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 11))
                            Text("全部播放")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 7)
                        .background(.pink, in: Capsule())
                        .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)

                    // Shuffle
                    Button {
                        let apiSongs = filteredSongs.map(\.asAPISong)
                        player.playAll(apiSongs.shuffled())
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "shuffle")
                                .font(.system(size: 11))
                            Text("随机播放")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 7)
                        .background(.quaternary, in: Capsule())
                        .foregroundStyle(.primary)
                    }
                    .buttonStyle(.plain)

                    // Open Finder folder
                    Button {
                        downloadManager.openDownloadsFolder()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "folder")
                                .font(.system(size: 12))
                            Text("在访达中显示文件夹")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.quaternary.opacity(0.7), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .help("打开本地下载目录")

                    Spacer()

                    // Info text & Clear
                    HStack(spacing: 10) {
                        Text("\(downloadManager.downloadedSongs.count) 首歌曲 · 占用空间 \(downloadManager.totalDiskSpaceText)")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)

                        Button {
                            showClearConfirm = true
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("清空全部已下载歌曲")
                    }
                }
            }
        }
    }

    // MARK: - Table Header

    private var tableHeaderView: some View {
        HStack(spacing: 0) {
            Text("#").frame(width: 36, alignment: .center)
            Text("标题").frame(maxWidth: .infinity, alignment: .leading)
            Text("艺人").frame(width: 150, alignment: .leading)
            Text("专辑").frame(width: 150, alignment: .leading)
            Text("大小").frame(width: 80, alignment: .leading)
            Image(systemName: "clock").frame(width: 60, alignment: .trailing)
            Text("操作").frame(width: 70, alignment: .center)
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(.secondary)
    }

    // MARK: - Song Row

    private func downloadedSongRow(song: DownloadedSong, index: Int) -> some View {
        let isPlaying = player.currentSong?.id == song.id
        let isHovered = hoveredSongId == song.id

        return HStack(spacing: 0) {
            // Index or Play indicator
            ZStack {
                if isPlaying {
                    Image(systemName: player.isPlaying ? "speaker.wave.2.fill" : "pause.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.pink)
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

            // Cover + Title
            HStack(spacing: 10) {
                coverImageView(for: song)
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 5))

                HStack(spacing: 8) {
                    Text(song.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(isPlaying ? .pink : .primary)
                        .lineLimit(1)

                    if isHovered || player.isLiked(song.id) {
                        Button {
                            player.toggleLike(for: song.asAPISong)
                        } label: {
                            Image(systemName: player.isLiked(song.id) ? "heart.fill" : "heart")
                                .font(.system(size: 11))
                                .foregroundStyle(player.isLiked(song.id) ? .pink : .secondary)
                        }
                        .buttonStyle(.plain)
                    }

                    // 本地离线标记
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.pink.opacity(0.8))
                        .help("已下载至本地")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Artist
            Text(song.artist)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(width: 150, alignment: .leading)

            // Album
            Text(song.album)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(width: 150, alignment: .leading)

            // File size
            Text(song.fileSizeText)
                .font(.system(size: 11).monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)

            // Duration
            Text(song.durationText)
                .font(.system(size: 12).monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .trailing)

            // Actions on Hover
            HStack(spacing: 10) {
                if isHovered {
                    Button {
                        downloadManager.revealInFinder(song.id)
                    } label: {
                        Image(systemName: "folder")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("在访达中显示")

                    Button {
                        downloadManager.deleteDownload(song.id)
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                            .foregroundStyle(.red.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    .help("删除此本地文件")
                }
            }
            .frame(width: 70, alignment: .center)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 6)
        .background(isHovered ? Color.primary.opacity(0.04) : .clear)
        .contentShape(Rectangle())
        .contextMenu {
            Button {
                playSong(song)
            } label: {
                Label("立即播放", systemImage: "play.fill")
            }

            Button {
                player.addToPlaylist(song.asAPISong)
            } label: {
                Label("添加到播放队列", systemImage: "text.badge.plus")
            }

            Divider()

            Button {
                downloadManager.revealInFinder(song.id)
            } label: {
                Label("在访达中显示", systemImage: "folder")
            }

            Button(role: .destructive) {
                downloadManager.deleteDownload(song.id)
            } label: {
                Label("删除已下载文件", systemImage: "trash")
            }
        }
    }

    @ViewBuilder
    private func coverImageView(for song: DownloadedSong) -> some View {
        if let localCover = downloadManager.localCoverURL(for: song.id),
           let nsImg = NSImage(contentsOf: localCover) {
            Image(nsImage: nsImg)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else if let urlStr = song.coverUrl, let url = URL(string: urlStr) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().aspectRatio(contentMode: .fill)
                default:
                    Rectangle().fill(.quaternary)
                        .overlay(Image(systemName: "music.note").foregroundStyle(.secondary))
                }
            }
        } else {
            Rectangle().fill(.quaternary)
                .overlay(Image(systemName: "music.note").foregroundStyle(.secondary))
        }
    }

    private func playSong(_ song: DownloadedSong) {
        let apiSongs = filteredSongs.map(\.asAPISong)
        if let idx = apiSongs.firstIndex(where: { $0.id == song.id }) {
            player.playAll(apiSongs, from: idx)
        } else {
            player.play(song.asAPISong)
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 64))
                .foregroundStyle(.tertiary)

            Text("暂无已下载歌曲")
                .font(.title2.bold())

            Text("在任意歌曲列表、歌单或底部播放栏中点击下载图标\n即可保存到本地，随时随地享受高质量离线音乐")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            Button {
                downloadManager.openDownloadsFolder()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "folder")
                    Text("打开本地下载目录")
                }
                .font(.system(size: 13, weight: .medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.quaternary, in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
        .padding(40)
    }
}
