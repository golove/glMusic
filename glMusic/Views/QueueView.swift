//
//  QueueView.swift
//  glMusic
//
//  Created by go love on 10/26/26.
//

import SwiftUI

enum QueueTab: Int, CaseIterable, Identifiable {
    case queue
    case history

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .queue: return "待播清单".localized
        case .history: return "播放历史".localized
        }
    }
}

struct QueueView: View {
    @Binding var selection: String?
    @Environment(PlayerManager.self) private var player
    @Environment(ThemeManager.self) private var themeManager
    @Environment(LanguageManager.self) private var languageManager

    @State private var selectedTab: QueueTab = .queue
    @State private var historyManager = HistoryManager.shared
    @State private var hoveredSongId: Int?
    @State private var draggingSongId: Int?
    @State private var dropTargetSongId: Int?

    init(selection: Binding<String?>? = nil) {
        self._selection = selection ?? .constant(nil)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // MARK: - Header
            HStack(alignment: .center, spacing: 10) {
                // 分段选择器
                Picker("", selection: $selectedTab) {
                    Text(String(format: "%@ (%d)", "待播".localized, player.playlist.count))
                        .tag(QueueTab.queue)
                    Text(String(format: "%@ (%d)", "历史".localized, historyManager.historyItems.count))
                        .tag(QueueTab.history)
                }
                .pickerStyle(.segmented)
                .frame(width: 175)

                Spacer()

                // 清空操作
                if selectedTab == .queue && !player.playlist.isEmpty {
                    Button("清空".localized) {
                        player.clearPlaylist()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(themeManager.accentColor)
                } else if selectedTab == .history && !historyManager.historyItems.isEmpty {
                    Button("清空".localized) {
                        historyManager.clearAll()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(themeManager.accentColor)
                }

                // 关闭按钮
                Button {
                    player.isShowingQueue = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.leading, 4)
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 10)

            Divider()

            // MARK: - List Content
            if selectedTab == .queue {
                queueContent
            } else {
                historyContent
            }
        }
        .frame(width: 330, height: 460)
        .background(.regularMaterial)
    }

    // MARK: - Queue Tab Content

    @ViewBuilder
    private var queueContent: some View {
        if player.playlist.isEmpty {
            VStack(spacing: 8) {
                Spacer()
                Image(systemName: "music.note.list")
                    .font(.system(size: 32))
                    .foregroundStyle(.tertiary)
                Text("清单为空".localized)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .frame(maxWidth: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(Array(player.playlist.enumerated()), id: \.element.id) { index, song in
                        QueueRowView(
                            song: song,
                            index: index,
                            isHovered: hoveredSongId == song.id,
                            isDragging: draggingSongId == song.id,
                            isDropTarget: dropTargetSongId == song.id && draggingSongId != song.id,
                            onHover: { h in hoveredSongId = h ? song.id : nil },
                            onDragStarted: { draggingSongId = song.id },
                            onDragEnded: {
                                draggingSongId = nil
                                dropTargetSongId = nil
                            },
                            onDropTargetChanged: { targeted in
                                dropTargetSongId = targeted ? song.id : nil
                            },
                            onReorder: { fromId, toId in
                                guard let fromIdx = player.playlist.firstIndex(where: { $0.id == fromId }),
                                      let toIdx = player.playlist.firstIndex(where: { $0.id == toId }) else { return }
                                withAnimation(.easeInOut(duration: 0.22)) {
                                    player.movePlaylistSong(fromIndex: fromIdx, toIndex: toIdx)
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }
        }
    }

    // MARK: - History Tab Content

    @ViewBuilder
    private var historyContent: some View {
        if historyManager.historyItems.isEmpty {
            VStack(spacing: 8) {
                Spacer()
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 32))
                    .foregroundStyle(.tertiary)
                Text("暂无播放历史".localized)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .frame(maxWidth: .infinity)
        } else {
            VStack(spacing: 0) {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(historyManager.historyItems) { item in
                            QueueHistoryRowView(
                                item: item,
                                isHovered: hoveredSongId == item.song.id,
                                onHover: { h in hoveredSongId = h ? item.song.id : nil },
                                onRemove: {
                                    historyManager.remove(item: item)
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                }

                Divider()

                // 底部通往完整历史页面的按钮
                Button {
                    player.isShowingQueue = false
                    selection = "history"
                } label: {
                    HStack(spacing: 4) {
                        Text("查看全部历史与统计".localized)
                            .font(.system(size: 11, weight: .medium))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .foregroundStyle(themeManager.accentColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.primary.opacity(0.02))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Subview for Queue Row

private struct QueueRowView: View {
    let song: APISong
    let index: Int
    let isHovered: Bool
    var isDragging: Bool = false
    var isDropTarget: Bool = false
    let onHover: (Bool) -> Void
    var onDragStarted: (() -> Void)? = nil
    var onDragEnded: (() -> Void)? = nil
    var onDropTargetChanged: ((Bool) -> Void)? = nil
    var onReorder: ((Int, Int) -> Void)? = nil

    @Environment(PlayerManager.self) private var player
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        let isCurrent = player.currentSong?.id == song.id

        HStack(spacing: 8) {
            // Drag Handle (悬停时清晰可见，便于鼠标拖动调整顺序)
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(isHovered ? themeManager.accentColor.opacity(0.85) : Color.secondary.opacity(0.2))
                .frame(width: 12)
                .help("拖拽调整待播顺序".localized)

            // Status / Play indicator
            ZStack {
                if isCurrent {
                    Image(systemName: player.isPlaying ? "speaker.wave.2.fill" : "pause.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(themeManager.accentColor)
                } else if isHovered {
                    Image(systemName: "play.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.primary)
                } else {
                    Text("\(index + 1)")
                        .font(.system(size: 11).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 20)

            // Cover
            SongCoverThumbnailView(song: song, size: 32)
                .frame(width: 32, height: 32)
                .clipShape(RoundedRectangle(cornerRadius: 4))

            // Title & Artist
            VStack(alignment: .leading, spacing: 2) {
                Text(song.name)
                    .font(.system(size: 12, weight: isCurrent ? .semibold : .regular))
                    .foregroundStyle(isCurrent ? themeManager.accentColor : .primary)
                    .lineLimit(1)

                Text(song.displayArtist)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if isHovered {
                HStack(spacing: 4) {
                    DownloadButton(song: song, iconSize: 12)
                        .frame(width: 22, height: 22)

                    QueueRemoveButton(
                        action: { player.removeFromPlaylist(song: song) },
                        tooltip: "从待播移除".localized
                    )
                }
                .padding(.trailing, 2)
            } else {
                HStack(spacing: 6) {
                    if DownloadManager.shared.isDownloaded(song.id) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(themeManager.accentColor.opacity(0.8))
                    }
                    Text(song.durationText)
                        .font(.system(size: 10).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    isDropTarget
                        ? themeManager.accentColor.opacity(0.18)
                        : (isHovered
                            ? Color.primary.opacity(0.06)
                            : (isCurrent ? themeManager.tintColor : Color.clear))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isDropTarget ? themeManager.accentColor : Color.clear, lineWidth: 1.2)
        )
        .opacity(isDragging ? 0.45 : 1.0)
        .contentShape(Rectangle())
        .onHover { onHover($0) }
        .onTapGesture {
            player.play(song)
        }
        .draggable("\(song.id)") {
            HStack(spacing: 8) {
                Image(systemName: "music.note")
                    .font(.system(size: 12))
                Text(song.name)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
            .onAppear {
                onDragStarted?()
            }
        }
        .dropDestination(for: String.self) { items, _ in
            onDragEnded?()
            guard let firstStr = items.first, let fromId = Int(firstStr) else { return false }
            onReorder?(fromId, song.id)
            return true
        } isTargeted: { targeted in
            onDropTargetChanged?(targeted)
            if !targeted {
                onDragEnded?()
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
                Label("下一首播放".localized, systemImage: "text.line.first.and.arrowtriangle.forward")
            }

            // MARK: - 添加到自建歌单
            AddToPlaylistMenu(song: song)

            Divider()

            Button {
                player.moveSongToTop(song)
            } label: {
                Label("移至顶部".localized, systemImage: "arrow.up.to.line")
            }

            Button {
                player.moveSongToBottom(song)
            } label: {
                Label("移至底部".localized, systemImage: "arrow.down.to.line")
            }

            Divider()

            Button(role: .destructive) {
                player.removeFromPlaylist(song: song)
            } label: {
                Label("从清单移除".localized, systemImage: "trash")
            }
        }
    }
}

// MARK: - Subview for Queue History Row

private struct QueueHistoryRowView: View {
    let item: PlayHistoryItem
    let isHovered: Bool
    let onHover: (Bool) -> Void
    var onRemove: () -> Void

    @Environment(PlayerManager.self) private var player
    @Environment(ThemeManager.self) private var themeManager

    private var song: APISong { item.song }

    var body: some View {
        let isCurrent = player.currentSong?.id == song.id

        HStack(spacing: 10) {
            // Status / Play indicator
            ZStack {
                if isCurrent {
                    Image(systemName: player.isPlaying ? "speaker.wave.2.fill" : "pause.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(themeManager.accentColor)
                } else if isHovered {
                    Image(systemName: "play.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.primary)
                } else {
                    Image(systemName: "clock")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(width: 22)

            // Cover
            SongCoverThumbnailView(song: song, size: 32)
                .frame(width: 32, height: 32)
                .clipShape(RoundedRectangle(cornerRadius: 4))

            // Title & Artist
            VStack(alignment: .leading, spacing: 2) {
                Text(song.name)
                    .font(.system(size: 12, weight: isCurrent ? .semibold : .regular))
                    .foregroundStyle(isCurrent ? themeManager.accentColor : .primary)
                    .lineLimit(1)

                Text(song.displayArtist)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if isHovered {
                HStack(spacing: 4) {
                    DownloadButton(song: song, iconSize: 12)
                        .frame(width: 22, height: 22)

                    QueueRemoveButton(
                        action: onRemove,
                        tooltip: "从历史中移除".localized
                    )
                }
                .padding(.trailing, 2)
            } else {
                Text(item.relativeTimeText)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            isHovered
                ? Color.primary.opacity(0.06)
                : (isCurrent ? themeManager.tintColor : Color.clear),
            in: RoundedRectangle(cornerRadius: 6)
        )
        .contentShape(Rectangle())
        .onHover { onHover($0) }
        .onTapGesture {
            player.play(song)
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

            Button(role: .destructive, action: onRemove) {
                Label("从历史中移除".localized, systemImage: "trash")
            }
        }
    }
}

// MARK: - Queue Remove Button (专属大热区悬停高亮按钮)

private struct QueueRemoveButton: View {
    let action: () -> Void
    var tooltip: String = "从待播移除".localized
    @State private var isHovered = false

    var body: some View {
        Button {
            action()
        } label: {
            ZStack {
                Circle()
                    .fill(isHovered ? Color.primary.opacity(0.12) : Color.clear)
                    .frame(width: 22, height: 22)

                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(isHovered ? .primary : .secondary)
            }
            .frame(width: 24, height: 24)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { h in
            withAnimation(.easeInOut(duration: 0.12)) {
                isHovered = h
            }
        }
        .help(tooltip)
    }
}

#Preview {
    QueueView()
        .environment(PlayerManager())
        .environment(ThemeManager.shared)
        .environment(LanguageManager.shared)
}
