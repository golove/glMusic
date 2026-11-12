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
    @Environment(ThemeManager.self) private var themeManager

    @State private var artist: APIArtistDetail?
    @State private var hotSongs: [APISong] = []
    @State private var albums: [APIAlbumDetail] = []
    @State private var isLoading = true
    // true 时使用 Preview 模拟数据；正常运行保持 false
    var isPreview: Bool = false

    let albumColumns = [GridItem(.adaptive(minimum: 150, maximum: 180), spacing: 20)]

    var body: some View {
        ZStack(alignment: .top) {
            
           

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                   

                if isLoading {
                    ProgressView("加载艺人资料...".localized)
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else {
                    // Hot 50 Songs
                    if !hotSongs.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                           

                            LazyVStack(spacing: 0) {
                                ForEach(Array(hotSongs.prefix(30).enumerated()), id: \.element.id) { idx, song in
                                    UnifiedSongRow(
                                        song: song,
                                        index: idx + 1,
                                        allSongs: hotSongs,
                                        showArtist: false,
                                        albumWidth: 180
                                    )
                                }
                            }
                        }
                    }

                    // Albums
                    if !albums.isEmpty {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("专辑".localized)
                                .font(.title2.bold())
                                .padding(.horizontal, 24)

                            LazyVGrid(columns: albumColumns, spacing: 20) {
                                ForEach(albums) { alb in
                                    AlbumGridCard(album: alb) {
                                        selection = "album_\(alb.id)"
                                    }
                                    .equatable() // 启用 Equatable 比较，阻断不必要的 body 重复求值
                                }
                            }
                            .padding(.horizontal, 24)
                        }
                    }

                    Spacer(minLength: 80)
                }
            }
        }
            .safeAreaInset(edge: .top, spacing: 0) {
                // 顶部常驻固定导航栏 (不随下方列表滚动)
                VStack(spacing:0){
                    albumHeader

                    Divider()
                        .padding(.horizontal, 24)
                        .opacity(0.4)
                }
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
                .foregroundStyle(themeManager.accentColor)
                .padding(8)
                .background(themeManager.tintColor, in: Circle())
              
            }
            .padding(.horizontal , 6)
            .buttonStyle(.plain)
            .keyboardShortcut("[", modifiers: [.command])
            .help("返回 (⌘[)".localized)

           
        }
     
       
        
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment:.leading){
         
            HStack(spacing: 24) {
                // Avatar (Downsampling + 后台硬解 + 磁盘二级缓存)
                CachedAsyncCoverView(
                    urlString: artist?.avatarUrl ?? artist?.coverUrl,
                    placeholderIcon: "music.mic",
                    targetSize: 160,
                    cornerRadius: 12,
                    cancelOnDisappear: true,
                    fixedSize: true
                )
                .shadow(color: .black.opacity(0.15), radius: 10, y: 4)

                // Info
                VStack(alignment: .leading, spacing: 6) {
                    Text("艺人".localized)
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    Text(artist?.name ?? "艺人".localized)
                        .font(.system(size: 28, weight: .bold))

                    HStack(spacing: 8) {
                        if let songsCount = artist?.musicSize, songsCount > 0 {
                            Text("%d 首单曲".localized(with: songsCount))
                        }
                        if let albumCount = artist?.albumSize, albumCount > 0 {
                            Text("· %d 张专辑".localized(with: albumCount))
                        }
                    }
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    Spacer()
                    HStack {
                        Text("热门歌曲".localized)
                            .font(.title2.bold())

        //                Spacer()

                        Button {
                            player.playAll(hotSongs)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 10))
                                Text("播放全部".localized)
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(themeManager.accentColor, in: Capsule())
                            .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    
                }
                .frame( height: 160)
            
            
            }
          
            
        }
    }

    private var albumHeader: some View {
        HStack(alignment: .top) {
            if let onBack = onBack {
                topPinnedBar(onBack: onBack)
            }
            // Header
            headerSection
                .frame(height: 190)
            Spacer()
        }
        .background(.ultraThinMaterial)
      
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
    .environment(ThemeManager.shared)
    .frame(width: 1100, height: 720)
}
