//
//  SongsView.swift
//  glMusic
//
//  Created by go love on 10/7/26.
//

import SwiftUI

struct SongsView: View {
    @Environment(PlayerManager.self) private var player
    @State private var songs: [APISong] = []
    @State private var isLoading = true
    @State private var hoveredSong: Int?
    @State private var chartName = "热歌榜"

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            

                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(songs.enumerated()), id: \.element.id) { idx, song in
                            SongTableRow(song: song, index: idx + 1,
                                         isPlaying: player.currentSong?.id == song.id,
                                         isHovered: hoveredSong == song.id)
                                .onHover { h in hoveredSong = h ? song.id : nil }
                                .onTapGesture {
                                    player.playAll(songs, from: idx)
                                }
                        }
                    }
//                    .padding(.bottom, 80)
                }
                .safeAreaInset(edge: .top, spacing: 0) {
                    // Header
                    VStack(alignment: .leading) {
                        VStack(alignment: .leading) {
                            Text("歌曲")
                                .font(.largeTitle.bold())
//                            Spacer()
                            if !songs.isEmpty {
                                Text("\(songs.count) 首歌曲 · \(chartName)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 12)
                        .padding(.bottom, 16)

                        if isLoading {
                            ProgressView("加载中...")
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            if !songs.isEmpty {
                                HStack(spacing: 12) {
                                    Button {
                                        player.playAll(songs)
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: "play.fill")
                                                .font(.system(size: 11))
                                            Text("播放")
                                                .font(.system(size: 13, weight: .semibold))
                                        }
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 6)
                                        .background(.pink, in: Capsule())
                                        .foregroundStyle(.white)
                                    }
                                    .buttonStyle(.plain)

                                    Button {
                                        player.playAll(songs.shuffled())
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: "shuffle")
                                                .font(.system(size: 11))
                                            Text("随机播放")
                                                .font(.system(size: 13, weight: .medium))
                                    }
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 6)
                                        .background(.quaternary, in: Capsule())
                                        .foregroundStyle(.primary)
                                    }
                                    .buttonStyle(.plain)

                                    Spacer()
                                }
                                .padding(.horizontal, 24)
                                .padding(.bottom, 12)
                            }

                            // Column headers
                            HStack(spacing: 0) {
                                Text("#").frame(width: 36, alignment: .center)
                                Text("标题").frame(maxWidth: .infinity, alignment: .leading)
                                Text("艺人").frame(width: 160, alignment: .leading)
                                Text("专辑").frame(width: 160, alignment: .leading)
                                Image(systemName: "clock").frame(width: 60, alignment: .trailing)
                            }
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 6)

                            Divider().padding(.horizontal, 24)
                    }
                    }
                    .background(.ultraThinMaterial)
               
            }
            }
        .task { await loadSongs() }
        }
      



    private func loadSongs() async {
        isLoading = true
        do {
            // 获取第一个榜单的歌曲
            let charts = try await NetworkManager.shared.toplist()
            if let first = charts.first {
                chartName = first.name
                songs = try await NetworkManager.shared.playlistTracks(id: first.id, limit: 50)
            }
        } catch {
            print("SongsView error: \(error)")
        }
        isLoading = false
    }
}

// MARK: - Song Table Row

struct SongTableRow: View {
    let song: APISong
    let index: Int
    let isPlaying: Bool
    let isHovered: Bool
    @Environment(PlayerManager.self) private var player

    var body: some View {
        HStack(spacing: 0) {
            // Number
            ZStack {
                if isPlaying {
                    Image(systemName: player.isPlaying ? "speaker.wave.2.fill" : "pause.fill")
                        .font(.system(size: 10)).foregroundStyle(.pink)
                } else if isHovered {
                    Image(systemName: "play.fill")
                        .font(.system(size: 10)).foregroundStyle(.primary)
                } else {
                    Text("\(index)")
                        .font(.system(size: 12).monospacedDigit()).foregroundStyle(.secondary)
                }
            }
            .frame(width: 36)

            // Cover + title
            HStack(spacing: 10) {
                AsyncImage(url: URL(string: song.coverUrl ?? "")) { phase in
                    switch phase {
                    case .success(let img): img.resizable().aspectRatio(contentMode: .fill)
                    default: Rectangle().fill(.quaternary)
                    }
                }
                .frame(width: 36, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 4))

                HStack(spacing: 8) {
                    Text(song.name)
                        .font(.system(size: 13))
                        .foregroundStyle(isPlaying ? .pink : .primary)
                        .lineLimit(1)

                    if isHovered || player.isLiked(song.id) || DownloadManager.shared.isDownloaded(song.id) || DownloadManager.shared.isDownloading(song.id) {
                        Button {
                            player.toggleLike(for: song)
                        } label: {
                            Image(systemName: player.isLiked(song.id) ? "heart.fill" : "heart")
                                .font(.system(size: 11))
                                .foregroundStyle(player.isLiked(song.id) ? .pink : .secondary)
                        }
                        .buttonStyle(.plain)

                        DownloadButton(song: song, iconSize: 11)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(song.displayArtist)
                .font(.system(size: 13)).foregroundStyle(.secondary).lineLimit(1)
                .frame(width: 160, alignment: .leading)

            Text(song.displayAlbum)
                .font(.system(size: 13)).foregroundStyle(.secondary).lineLimit(1)
                .frame(width: 160, alignment: .leading)

            Text(song.durationText)
                .font(.system(size: 13).monospacedDigit()).foregroundStyle(.secondary)
                .frame(width: 60, alignment: .trailing)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 6)
        .background(isHovered ? Color.primary.opacity(0.04) : .clear)
        .contentShape(Rectangle())
        .contextMenu {
            Button {
                player.play(song)
            } label: {
                Label("立即播放", systemImage: "play.fill")
            }

            Button {
                player.playNext(song)
            } label: {
                Label("下一首播放", systemImage: "text.insert")
            }

            Button {
                player.addToPlaylist(song)
            } label: {
                Label("添加到播放列表", systemImage: "text.badge.plus")
            }

            Divider()

            if DownloadManager.shared.isDownloaded(song.id) {
                Button {
                    DownloadManager.shared.revealInFinder(song.id)
                } label: {
                    Label("在访达中显示", systemImage: "folder")
                }

                Button(role: .destructive) {
                    DownloadManager.shared.deleteDownload(song.id)
                } label: {
                    Label("删除已下载文件", systemImage: "trash")
                }
            } else {
                Button {
                    DownloadManager.shared.downloadSong(song)
                } label: {
                    Label("下载歌曲", systemImage: "arrow.down.circle")
                }
            }

            Divider()

            Button {
                player.toggleLike(for: song)
            } label: {
                Label(player.isLiked(song.id) ? "取消喜欢" : "喜欢这首歌",
                      systemImage: player.isLiked(song.id) ? "heart.slash" : "heart")
            }
        }
    }
}

#Preview {
    SongsView()
        .environment(PlayerManager())
}
