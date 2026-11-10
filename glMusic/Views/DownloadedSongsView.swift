//
//  DownloadedSongsView.swift
//  glMusic
//
//  Created by go love on 10/29/26.
//

import SwiftUI

struct DownloadedSongsView: View {
    @Environment(PlayerManager.self) private var player
    @Environment(ThemeManager.self) private var themeManager
    @State private var downloadManager = DownloadManager.shared
    @State private var searchText: String = ""
    @State private var hoveredSongId: Int?
    @State private var showClearConfirm: Bool = false
    @State private var filterMode: FilterMode = .all
    @State private var isDragTargeted: Bool = false

    enum FilterMode: String, CaseIterable, Identifiable {
        case all = "全部"
        case local = "本地导入"
        case downloaded = "已下载"
        var id: String { rawValue }

        var displayName: String {
            rawValue.localized
        }
    }

    private var filteredSongs: [DownloadedSong] {
        var list = downloadManager.downloadedSongs
        switch filterMode {
        case .all:
            break
        case .local:
            list = list.filter(\.isLocal)
        case .downloaded:
            list = list.filter { !$0.isLocal }
        }

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
                .padding(.bottom, 12)

            // 导入进度提示横条
            if let statusMsg = downloadManager.importStatusMessage {
                HStack(spacing: 8) {
                    if downloadManager.isImporting {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                    Text(statusMsg)
                        .font(.system(size: 12, weight: .medium))
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(themeManager.tintColor, in: RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal, 24)
                .padding(.bottom, 10)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Content
            if downloadManager.downloadedSongs.isEmpty {
                emptyStateView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Table header
                tableHeaderView
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
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
        // 支持将本地音频文件或文件夹直接拖拽入窗口导入
        .dropDestination(for: URL.self) { urls, _ in
            guard !urls.isEmpty else { return false }
            Task {
                await downloadManager.importLocalSongs(from: urls)
            }
            return true
        } isTargeted: { targeted in
            withAnimation(.easeInOut(duration: 0.15)) {
                isDragTargeted = targeted
            }
        }
        .overlay {
            if isDragTargeted {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(themeManager.accentColor, style: StrokeStyle(lineWidth: 2, dash: [8, 4]))
                    .background(themeManager.accentColor.opacity(0.08))
                    .padding(16)
                    .overlay {
                        VStack(spacing: 8) {
                            Image(systemName: "arrow.down.doc.fill")
                                .font(.system(size: 44))
                                .foregroundStyle(themeManager.accentColor)
                            Text("松开以导入本地音频文件到资料库".localized)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.primary)
                            Text("支持 MP3、FLAC、M4A、WAV、AAC、AIFF、OGG 及伴生 LRC 歌词".localized)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .allowsHitTesting(false)
            }
        }
        .confirmationDialog(
            "确认清空所有已下载歌曲？".localized,
            isPresented: $showClearConfirm,
            titleVisibility: .visible
        ) {
            Button("清空全部下载文件".localized, role: .destructive) {
                downloadManager.clearAllDownloads()
            }
            Button("取消".localized, role: .cancel) { }
        } message: {
            Text("将从本地磁盘删除全部已下载与已导入的音频、封面和歌词文件。".localized)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(themeManager.accentColor)
                    Text("本地与下载".localized)
                        .font(.largeTitle.bold())
                }

                Spacer()

                // Search field
                if !downloadManager.downloadedSongs.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        TextField("在歌曲中搜索...".localized, text: $searchText)
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

            HStack(spacing: 12) {
                if !downloadManager.downloadedSongs.isEmpty {
                    // Play all
                    Button {
                        let apiSongs = filteredSongs.map(\.asAPISong)
                        player.playAll(apiSongs)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 11))
                            Text("全部播放".localized)
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 7)
                        .background(themeManager.accentColor, in: Capsule())
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
                            Text("随机播放".localized)
                                .font(.system(size: 13, weight: .medium))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 7)
                        .background(.quaternary, in: Capsule())
                        .foregroundStyle(.primary)
                    }
                    .buttonStyle(.plain)
                }

                // 导入本地歌曲按钮 (始终保留在顶部)
                Button {
                    downloadManager.openFilePickerToImport()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 12))
                        Text("导入本地歌曲".localized)
                            .font(.system(size: 13, weight: .medium))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(themeManager.tintColor, in: Capsule())
                    .foregroundStyle(themeManager.accentColor)
                }
                .buttonStyle(.plain)
                .keyboardShortcut("o", modifiers: [.command])
                .help("选择本地音频文件或文件夹导入资料库 (支持拖拽，快捷键 ⌘O)".localized)

                // Open Finder folder
                if !downloadManager.downloadedSongs.isEmpty {
                    Button {
                        downloadManager.openDownloadsFolder()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "folder")
                                .font(.system(size: 12))
                            Text("在访达中显示文件夹".localized)
                                .font(.system(size: 12, weight: .medium))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.quaternary.opacity(0.7), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .help("打开本地保存目录".localized)
                }

                Spacer()

                if !downloadManager.downloadedSongs.isEmpty {
                    // 分类筛选 Pills (若存在多种来源)
                    if downloadManager.localImportedCount > 0 && downloadManager.remoteDownloadedCount > 0 {
                        HStack(spacing: 4) {
                            ForEach(FilterMode.allCases) { mode in
                                let count = countFor(mode)
                                Button {
                                    filterMode = mode
                                } label: {
                                    Text("\(mode.displayName) (\(count))")
                                        .font(.system(size: 11, weight: filterMode == mode ? .semibold : .regular))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(filterMode == mode ? themeManager.tintColor : Color.clear, in: Capsule())
                                        .foregroundStyle(filterMode == mode ? themeManager.accentColor : .secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Info text & Clear
                    HStack(spacing: 10) {
                        Text(String(format: "%d 首 · %@".localized, downloadManager.downloadedSongs.count, downloadManager.totalDiskSpaceText))
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
                        .help("清空全部歌曲".localized)
                    }
                }
            }
        }
    }

    private func countFor(_ mode: FilterMode) -> Int {
        switch mode {
        case .all:
            return downloadManager.downloadedSongs.count
        case .local:
            return downloadManager.localImportedCount
        case .downloaded:
            return downloadManager.remoteDownloadedCount
        }
    }

    // MARK: - Table Header

    private var tableHeaderView: some View {
        HStack(spacing: 0) {
            Text("#").frame(width: 36, alignment: .center)
            Text("标题".localized).frame(maxWidth: .infinity, alignment: .leading)
            Text("艺人".localized).frame(width: 150, alignment: .leading)
            Text("专辑".localized).frame(width: 150, alignment: .leading)
            Text("大小".localized).frame(width: 80, alignment: .leading)
            Image(systemName: "clock").frame(width: 60, alignment: .trailing)
            Text("操作".localized).frame(width: 70, alignment: .center)
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

            // Cover + Title
            HStack(spacing: 10) {
                coverImageView(for: song)
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 5))

                HStack(spacing: 8) {
                    Text(song.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(isPlaying ? themeManager.accentColor : .primary)
                        .lineLimit(1)

                    if isHovered || player.isLiked(song.id) {
                        Button {
                            player.toggleLike(for: song.asAPISong)
                        } label: {
                            Image(systemName: player.isLiked(song.id) ? "heart.fill" : "heart")
                                .font(.system(size: 11))
                                .foregroundStyle(player.isLiked(song.id) ? themeManager.accentColor : .secondary)
                        }
                        .buttonStyle(.plain)
                    }

                    // 本地或已下载标记
                    if song.isLocal {
                        Text("本地".localized)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(themeManager.accentColor)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(themeManager.tintColor, in: RoundedRectangle(cornerRadius: 3))
                            .help("本地导入音频".localized)
                    } else {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(themeManager.accentColor.opacity(0.8))
                            .help("已下载至本地".localized)
                    }
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
                    .help("在访达中显示".localized)

                    Button {
                        downloadManager.deleteDownload(song.id)
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                            .foregroundStyle(.red.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    .help((song.isLocal ? "从资料库移除" : "删除此本地文件").localized)
                }
            }
            .frame(width: 70, alignment: .center)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 6)
        .frame(height: 48)
        .background(isHovered ? Color.primary.opacity(0.04) : .clear)
        .contentShape(Rectangle())
        .contextMenu {
            Button {
                playSong(song)
            } label: {
                Label("立即播放".localized, systemImage: "play.fill")
            }

            Button {
                player.addToPlaylist(song.asAPISong)
            } label: {
                Label("添加到播放队列".localized, systemImage: "text.badge.plus")
            }

            Divider()

            Button {
                downloadManager.revealInFinder(song.id)
            } label: {
                Label("在访达中显示".localized, systemImage: "folder")
            }

            Button(role: .destructive) {
                downloadManager.deleteDownload(song.id)
            } label: {
                Label((song.isLocal ? "从资料库移除" : "删除已下载文件").localized, systemImage: "trash")
            }
        }
    }

    @ViewBuilder
    private func coverImageView(for song: DownloadedSong) -> some View {
        SongCoverThumbnailView(songId: song.id, coverUrl: song.coverUrl, size: 36)
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
            Image(systemName: "music.note.house")
                .font(.system(size: 60))
                .foregroundStyle(.tertiary)

            Text("暂无本地与下载歌曲".localized)
                .font(.title2.bold())

            Text("点击下方按钮选择音频文件，或直接将音频文件/文件夹拖拽至此窗口".localized)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)

            Button {
                downloadManager.openFilePickerToImport()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 13))
                    Text("导入本地歌曲".localized)
                        .font(.system(size: 13, weight: .semibold))
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 10)
                .background(themeManager.accentColor, in: Capsule())
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
    }
}

#Preview {
    DownloadedSongsView()
        .environment(PlayerManager())
        .environment(ThemeManager.shared)
}
