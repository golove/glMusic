//
//  QueueView.swift
//  glMusic
//
//  Created by go love on 10/26/26.
//

import SwiftUI

struct QueueView: View {
    @Environment(PlayerManager.self) private var player
    @Environment(ThemeManager.self) private var themeManager
    @State private var hoveredSongId: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("待播清单")
                        .font(.system(size: 15, weight: .bold))
                    Text("\(player.playlist.count) 首歌曲")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if !player.playlist.isEmpty {
                    Button("清空") {
                        player.clearPlaylist()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundStyle(themeManager.accentColor)
                }

                Button {
                    player.isShowingQueue = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.leading, 8)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Divider()

            // List
            if player.playlist.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "music.note.list")
                        .font(.system(size: 32))
                        .foregroundStyle(.tertiary)
                    Text("清单为空")
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
                                onHover: { h in hoveredSongId = h ? song.id : nil }
                            )
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                }
            }
        }
        .frame(width: 320, height: 460)
        .background(.regularMaterial)
    }
}

// MARK: - Subview for Queue Row

private struct QueueRowView: View {
    let song: APISong
    let index: Int
    let isHovered: Bool
    let onHover: (Bool) -> Void
    @Environment(PlayerManager.self) private var player
    @Environment(ThemeManager.self) private var themeManager

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
                    Text("\(index + 1)")
                        .font(.system(size: 11).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 22)

            // Cover
            AsyncImage(url: URL(string: song.coverUrl ?? "")) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().aspectRatio(contentMode: .fill)
                default:
                    Rectangle().fill(.quaternary)
                }
            }
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
                HStack(spacing: 8) {
                    DownloadButton(song: song, iconSize: 11)

                    Button {
                        player.removeFromPlaylist(song: song)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.trailing, 4)
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
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
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
    }
}

#Preview {
    QueueView()
        .environment(PlayerManager())
}
