//
//  AlbumDetailView.swift
//  glMusic
//
//  Created by go love on 10/26/26.
//

import SwiftUI

struct AlbumDetailView: View {
    let albumId: Int
    var onBack: (() -> Void)? = {
        print("press back")
    }
    @Environment(PlayerManager.self) private var player

    @State private var album: APIAlbumDetail?
    @State private var songs: [APISong] = []
    @State private var isLoading = true
    @State private var isShowingFullDesc = false

    var body: some View {
        ZStack(alignment: .top){
          


            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                   

                if isLoading {
                    ProgressView("加载专辑中...")
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if songs.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "music.note")
                            .font(.system(size: 36))
                            .foregroundStyle(.tertiary)
                        Text("暂无歌曲数据")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 200)
                } else {
                 

                 

                    // Tracklist
                    LazyVStack(spacing: 0) {
                        ForEach(Array(songs.enumerated()), id: \.element.id) { idx, song in
                            UnifiedSongRow(
                                song: song,
                                index: idx + 1,
                                allSongs: songs,
                                showCover: false,
                                showAlbum: false,
                                artistWidth: 160
                            )
                        }
                    }

                    // Album Description & Release info
                    if let desc = album?.description, !desc.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("专辑介绍")
                                .font(.headline)

                            Text(desc)
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                                .lineLimit(isShowingFullDesc ? nil : 4)

                            Button(isShowingFullDesc ? "收起" : "更多") {
                                isShowingFullDesc.toggle()
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 12))
                            .foregroundStyle(.pink)
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 24)
                    }

                    if let pubDate = album?.publishDateText, !pubDate.isEmpty {
                        Text("发行于 \(pubDate)")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 24)
                            .padding(.top, 16)
                    }

                    Spacer(minLength: 80)
                }
            }
//                .padding(.vertical,240)
        }
            .safeAreaInset(edge: .top, spacing: 0) {
                // 顶部常驻固定导航栏 (不随下方列表滚动)
                albumHeader
            }
            
        .task { await loadAlbum() }
    }
        .padding(.top,6)
}

    // MARK: - Top Pinned Bar

    private func topPinnedBar(onBack: @escaping () -> Void) -> some View {
       
            Button(action: onBack) {
                HStack(spacing: 5) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .bold))
   
                }
                .padding(8)
                .foregroundStyle(.pink)
                .background(.pink.opacity(0.12), in: Circle())
                
            }
            .padding(.horizontal , 6)
            .buttonStyle(.plain)
            .keyboardShortcut("[", modifiers: [.command])
            .help("返回 (⌘[)")
            
 
        


    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack(alignment: .top, spacing: 24) {
            // Album Art
            AsyncImage(url: URL(string: album?.coverUrl ?? album?.picUrl ?? "")) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().aspectRatio(contentMode: .fill)
                default:
                    Rectangle().fill(.quaternary)
                        .overlay(Image(systemName: "square.stack").font(.largeTitle).foregroundStyle(.tertiary))
                }
            }
            .frame(width: 180, height: 180)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.18), radius: 12, y: 6)

            // Info
            VStack(alignment: .leading, spacing: 6) {
                Text("专辑")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Text(album?.name ?? "专辑")
                    .font(.system(size: 26, weight: .bold))
                    .lineLimit(2)

                if let artistName = album?.artist?.name {
                    Text(artistName)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.pink)
                }

                HStack(spacing: 6) {
                    if let year = album?.publishYear, !year.isEmpty {
                        Text(year)
                    }
                    if let size = album?.size, size > 0 {
                        Text("· \(size) 首歌曲")
                    }
                    if let company = album?.company, !company.isEmpty {
                        Text("· \(company)")
                    }
                }
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                
                Spacer()
                
                // Actions (Play all & Shuffle & Download)
                PlaybackActionBar(
                    songs: songs,
                    playTitle: "播放全部",
                    downloadTitle: "下载专辑",
                    downloadHelpText: "下载此专辑全部歌曲到本地"
                )

                .padding(.bottom, 20)
                
            }

        }
        .frame(height: 190)
    }
    
    private var albumHeader:some View{
        VStack{
            if let onBack = onBack {
              VStack{
                    HStack(alignment: .top){
                        topPinnedBar(onBack: onBack)
                        
                        // Header
                        headerSection
                            .padding(.top,12)
                        Spacer()
                    }
                    // Column headers
                    HStack(spacing: 0) {
                        Text("#").frame(width: 36, alignment: .center)
                        Text("标题").frame(maxWidth: .infinity, alignment: .leading)
                        Text("艺人").frame(width: 160, alignment: .leading)
                        Image(systemName: "clock").frame(width: 60, alignment: .trailing)
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 6)

                
                }
                .zIndex(3)
                .background(.ultraThinMaterial)
                
            }
        }
    }

    private func loadAlbum() async {
        isLoading = true
        do {
            let res = try await NetworkManager.shared.albumDetail(id: albumId)
            album = res.album
            songs = res.songs ?? []
        } catch {
            print("加载专辑失败: \(error)")
        }
        isLoading = false
    }
}

#Preview {
    AlbumDetailView(albumId: 32311)
        .environment(PlayerManager())
}
