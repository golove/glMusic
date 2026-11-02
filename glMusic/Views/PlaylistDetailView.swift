//
//  PlaylistDetailView.swift
//  glMusic
//
//  Created by go love on 10/24/26.
//

import SwiftUI

struct PlaylistDetailView: View {
    let playlistId: Int
    var onBack: (() -> Void)? = {
        print("press back")
    }
    @Environment(PlayerManager.self) private var player

    @State private var playlist: APIPlaylist?
    @State private var songs: [APISong] = []
    @State private var isLoading = true
    @State private var hoveredSong: Int?
    
  

    var body: some View {
        ZStack(alignment: .top) {
           

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                  

                if isLoading {
                    ProgressView("加载中...")
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if songs.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "music.note")
                            .font(.system(size: 36))
                            .foregroundStyle(.tertiary)
                        Text("歌单暂无歌曲")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 200)
                } else {
                   

                   

                    // Song list
                    LazyVStack(spacing: 0) {
                        ForEach(Array(songs.enumerated()), id: \.element.id) { idx, song in
                            PlaylistSongRow(
                                song: song,
                                index: idx + 1,
                                isPlaying: player.currentSong?.id == song.id,
                                isHovered: hoveredSong == song.id
                            )
                            .onHover { h in hoveredSong = h ? song.id : nil }
                            .onTapGesture {
                                player.playAll(songs, from: idx)
                            }
                        }
                    }
//                    .padding(.bottom, 80)
                }
            }
                
        }
            .safeAreaInset(edge: .top, spacing: 0) {
                // 顶部常驻固定导航栏 (不随下方列表滚动)
                if let onBack = onBack {
                    
                        VStack{
                            HStack(alignment: .top){
                                topPinnedBar(onBack: onBack)
                                
                                // MARK: - Header
                             
                                    headerSection
                                    .padding(.top, 12)
                               
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
                       
                        .background(.ultraThinMaterial)
                        .zIndex(1)
                      
                    
                }
            }
        .task { await loadPlaylist() }
    }
        .padding(.top,6)
}

    // MARK: - Top Pinned Bar

    private func topPinnedBar(onBack: @escaping () -> Void) -> some View {

            Button(action: onBack) {
                
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .bold))
            
                .foregroundStyle(.pink)
                .padding(8)
                .background(.pink.opacity(0.12), in: Circle())

            }
            .padding(.horizontal , 6)
            .buttonStyle(.plain)
            .keyboardShortcut("[", modifiers: [.command])
            .help("返回 (⌘[)")


        
        
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .top){
            // Cover
            AsyncImage(url: URL(string: playlist?.displayCover ?? "")) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().aspectRatio(contentMode: .fill)
                default:
                    Rectangle().fill(.quaternary)
                        .overlay(
                            Image(systemName: "music.note.list")
                                .font(.largeTitle)
                                .foregroundStyle(.tertiary)
                        )
                }
            }
            .frame(width: 180, height: 180)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.15), radius: 10, y: 5)

            // Info
            VStack(alignment: .leading, spacing: 8) {
                Text("歌单")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Text(playlist?.name ?? "歌单")
                    .font(.title.bold())
                    .lineLimit(2)

                if let desc = playlist?.description, !desc.isEmpty {
                    Text(desc)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }

                if let count = playlist?.trackCount {
                    Text("\(count) 首歌曲")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()

                // Play all + count
                HStack(spacing: 12) {
                    Button {
                        player.playAll(songs)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 12))
                            Text("播放全部")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.pink, in: Capsule())
                        .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)

                    Button {
                        player.playAll(songs.shuffled())
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "shuffle")
                                .font(.system(size: 12))
                            Text("随机播放")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.quaternary, in: Capsule())
                        .foregroundStyle(.primary)
                    }
                    .buttonStyle(.plain)

                    // 下载全部歌曲
                    Button {
                        DownloadManager.shared.downloadAll(songs)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.down.circle")
                                .font(.system(size: 12))
                            Text("下载全部")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.quaternary, in: Capsule())
                        .foregroundStyle(.primary)
                    }
                    .buttonStyle(.plain)
                    .help("下载此歌单中的全部歌曲到本地")

                    Spacer()
                }
//                .padding(.horizontal, 24)
                .padding(.bottom, 20)
               
            }
            .padding(.top, 8)
            .frame(height: 200)
        }
    }

    // MARK: - Load Data

    private func loadPlaylist() async {
        isLoading = true
        do {
            // 并发加载歌单信息和歌曲列表
            async let detailTask = NetworkManager.shared.playlistDetail(id: playlistId)
            async let songsTask = NetworkManager.shared.playlistTracks(id: playlistId, limit: 200)
            let (detail, fetchedSongs) = try await (detailTask, songsTask)
            playlist = detail
            songs = fetchedSongs
        } catch {
            print("PlaylistDetail error: \(error)")
        }
        isLoading = false
    }
}

// MARK: - Song Row

struct PlaylistSongRow: View {
    let song: APISong
    let index: Int
    let isPlaying: Bool
    let isHovered: Bool
    @Environment(PlayerManager.self) private var player

    var body: some View {
        HStack(spacing: 0) {
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
    PlaylistDetailView(playlistId: 1)
        .environment(PlayerManager())
        .frame(height: 800)
}
