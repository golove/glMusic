//
//  DailyRecommendView.swift
//  glMusic
//
//  Created by go love on 10/26/26.
//

import SwiftUI

struct DailyRecommendView: View {
    @Environment(PlayerManager.self) private var player
    @State private var songs: [APISong] = []
    @State private var isLoading = true
    @State private var hoveredSongId: Int?
    @State private var errorMessage: String?

    private var todayDayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: Date())
    }

    private var todayWeekday: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "EEEE"
        return formatter.string(from: Date())
    }

    var body: some View {
        VStack{
            
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Header
                  

                    if isLoading {
                        ProgressView("加载每日推荐...")
                            .frame(maxWidth: .infinity, minHeight: 200)
                        
                      
                        
                    } else if let error = errorMessage {
                        VStack(spacing: 12) {
                            Image(systemName: "lock.circle")
                                .font(.system(size: 40))
                                .foregroundStyle(.tertiary)
                            Text(error)
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            Text("每日推荐需要登录网易云音乐账号")
                                .font(.subheadline)
                                .foregroundStyle(.tertiary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 200)
                    } else if songs.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "music.note")
                                .font(.system(size: 36))
                                .foregroundStyle(.tertiary)
                            Text("暂无推荐歌曲")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 200)
                    } else {
                       

                       

                        // Song List
                        LazyVStack(spacing: 0) {
                            ForEach(Array(songs.enumerated()), id: \.element.id) { idx, song in
                                let isPlaying = player.currentSong?.id == song.id
                                let isHovered = hoveredSongId == song.id

                                HStack(spacing: 0) {
                                    // Index
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
                                            Text("\(idx + 1)")
                                                .font(.system(size: 12).monospacedDigit())
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .frame(width: 36)

                                    // Cover
                                    AsyncImage(url: URL(string: song.coverUrl ?? "")) { phase in
                                        switch phase {
                                        case .success(let img):
                                            img.resizable().aspectRatio(contentMode: .fill)
                                        default:
                                            Rectangle().fill(.quaternary)
                                        }
                                    }
                                    .frame(width: 36, height: 36)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                                    .padding(.trailing, 10)

                                    // Title + Like
                                    HStack(spacing: 8) {
                                        Text(song.name)
                                            .font(.system(size: 13, weight: .medium))
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
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                    // Artist
                                    Text(song.displayArtist)
                                        .font(.system(size: 13))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .frame(width: 160, alignment: .leading)

                                    // Album
                                    Text(song.displayAlbum)
                                        .font(.system(size: 13))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .frame(width: 160, alignment: .leading)

                                    // Duration
                                    Text(song.durationText)
                                        .font(.system(size: 13).monospacedDigit())
                                        .foregroundStyle(.secondary)
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
                                .onHover { h in hoveredSongId = h ? song.id : nil }
                                .onTapGesture {
                                    player.playAll(songs, from: idx)
                                }
                            }
                        }
//                        .padding(.bottom, 80)
                    }
                }
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            // 顶部常驻固定导航栏 (不随下方列表滚动)
            VStack{
               
                headerSection
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
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
            .frame(height: 200)
            .background(.ultraThinMaterial)
            .zIndex(2)
        }
        
           
        .task { await loadDailySongs() }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: 24) {
            // Calendar style Artwork
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(LinearGradient(colors: [.pink, .red.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 140, height: 140)
                    .shadow(color: .pink.opacity(0.3), radius: 12, y: 6)

                VStack(spacing: 4) {
                    Text(todayWeekday)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .textCase(.uppercase)

                    Text(todayDayNumber)
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
            }

            // Info
            VStack(alignment: .leading, spacing: 6) {
                Text("专属推荐")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Text("每日推荐")
                    .font(.system(size: 28, weight: .bold))

                Text("符合你口味的专属歌单 · 每日 6:00 更新")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                // Action: Play all
                HStack(spacing: 14) {
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
                    .help("下载全部推荐歌曲到本地")

                    Text("\(songs.count) 首推荐")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Spacer()
                }
//                    .padding(.horizontal, 24)
                .padding(.bottom, 12)
            }

       
        }
    }

    private func loadDailySongs() async {
        isLoading = true
        errorMessage = nil
        do {
            if !NetworkManager.shared.isLoggedIn {
                errorMessage = "请先登录账号"
            } else {
                songs = try await NetworkManager.shared.dailyRecommendSongs()
            }
        } catch {
            print("加载每日推荐失败: \(error)")
            errorMessage = "获取每日推荐失败，请确认是否已登录"
        }
        isLoading = false
    }
}

#Preview {
    DailyRecommendView()
        .environment(PlayerManager())
}
