//
//  ArtistDetailView.swift
//  glMusic
//
//  Created by go love on 10/26/26.
//

import SwiftUI

struct ArtistDetailView: View {
    let artistId: Int
    @Binding var selection: String?
    var onBack: (() -> Void)? = {
        print("press back")
    }
    @Environment(PlayerManager.self) private var player

    @State private var artist: APIArtistDetail?
    @State private var hotSongs: [APISong] = []
    @State private var albums: [APIAlbumDetail] = []
    @State private var isLoading = true
    @State private var hoveredSongId: Int?
    // true 时使用 Preview 模拟数据；正常运行保持 false
    var isPreview: Bool = false

    let albumColumns = [GridItem(.adaptive(minimum: 150, maximum: 180), spacing: 20)]

    var body: some View {
        ZStack(alignment: .top) {
            
           

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                   

                if isLoading {
                    ProgressView("加载艺人资料...")
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else {
                    // Hot 50 Songs
                    if !hotSongs.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                           

                            LazyVStack(spacing: 0) {
                                ForEach(Array(hotSongs.prefix(30).enumerated()), id: \.element.id) { idx, song in
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

                                        // Title
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

                                        // Album
                                        Text(song.displayAlbum)
                                            .font(.system(size: 13))
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                            .frame(width: 180, alignment: .leading)

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
                                    .onHover { h in hoveredSongId = h ? song.id : nil }
                                    .onTapGesture {
                                        player.playAll(hotSongs, from: idx)
                                    }
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
                        }
                    }

                    // Albums
                    if !albums.isEmpty {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("专辑")
                                .font(.title2.bold())
                                .padding(.horizontal, 24)

                            LazyVGrid(columns: albumColumns, spacing: 20) {
                                ForEach(albums) { alb in
                                    AlbumGridCard(album: alb) {
                                        selection = "album_\(alb.id)"
                                    }
                                }
                            }
                            .padding(.horizontal, 24)
                        }
                    }

                    Spacer(minLength: 80)
                }
            }
                
//                .padding(.vertical,200)
        }
            .safeAreaInset(edge: .top, spacing: 0) {
                // 顶部常驻固定导航栏 (不随下方列表滚动)
                albumHeader
            }
        .task {
            if isPreview {
                  artist = ArtistDetailPreviewData.artist
                  hotSongs = ArtistDetailPreviewData.hotSongs
                  albums = ArtistDetailPreviewData.albums
                  isLoading = false
              } else {
                  await loadArtist()
              }
        }
    }
        .padding(.top,6)
}

    // MARK: - Top Pinned Bar

    private func topPinnedBar(onBack: @escaping () -> Void) -> some View {
        HStack {
            Button(action: onBack) {
                HStack(spacing: 5) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(.pink)
                .padding(8)
                .background(.pink.opacity(0.12), in: Circle())
              
            }
            .padding(.horizontal , 6)
            .buttonStyle(.plain)
            .keyboardShortcut("[", modifiers: [.command])
            .help("返回 (⌘[)")

           
        }
     
       
        
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment:.leading){
         
            HStack(spacing: 24) {
                // Avatar
                AsyncImage(url: URL(string: artist?.picUrl ?? artist?.img1v1Url ?? "")) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().aspectRatio(contentMode: .fill)
                    default:
                        Circle().fill(.quaternary)
                            .overlay(Image(systemName: "music.mic").font(.largeTitle).foregroundStyle(.tertiary))
                    }
                }
                .frame(width: 160, height: 160)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.15), radius: 10, y: 4)

                // Info
                VStack(alignment: .leading, spacing: 6) {
                    Text("艺人")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    Text(artist?.name ?? "艺人")
                        .font(.system(size: 28, weight: .bold))

                    HStack(spacing: 8) {
                        if let songsCount = artist?.musicSize, songsCount > 0 {
                            Text("\(songsCount) 首单曲")
                        }
                        if let albumCount = artist?.albumSize, albumCount > 0 {
                            Text("· \(albumCount) 张专辑")
                        }
                    }
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    Spacer()
                    HStack {
                        Text("热门歌曲")
                            .font(.title2.bold())

        //                Spacer()

                        Button {
                            player.playAll(hotSongs)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 10))
                                Text("播放全部")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.pink, in: Capsule())
                            .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                    }
//                    .padding(.top,10)
                   
                    
                }
            
            
            }
          
            
        }
        .padding(.vertical,10)
    }
    
    private var albumHeader:some View{
        VStack{
            if let onBack = onBack {
                HStack(alignment: .top){
                    topPinnedBar(onBack: onBack)
                    // Header
                    headerSection
                        .frame(height: 190)
                    Spacer()
                }
                .background(.ultraThinMaterial)
                .zIndex(1)
            }
        }
    }

    private func loadArtist() async {
        isLoading = true
        do {
            async let detailTask = NetworkManager.shared.artistDetail(id: artistId)
            async let albumTask = NetworkManager.shared.artistAlbums(id: artistId)
            let (detail, alb) = try await (detailTask, albumTask)
            artist = detail.artist
            hotSongs = detail.hotSongs ?? []
            albums = alb
        } catch {
            print("加载艺人详情失败: \(error)")
        }
        isLoading = false
    }
}


#Preview("艺人详情页 - 模拟数据") {
    ArtistDetailView(
        artistId: ArtistDetailPreviewData.artist.id,
        selection: .constant(nil),
        isPreview: true
    )
    .environment(PlayerManager())
    .frame(width: 1100, height: 720)
}
