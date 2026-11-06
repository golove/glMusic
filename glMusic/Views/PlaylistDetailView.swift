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
    @Environment(ThemeManager.self) private var themeManager

    @State private var playlist: APIPlaylist?
    @State private var songs: [APISong] = []
    @State private var isLoading = true
    @State private var hoveredSong: Int?
    
  

    var body: some View {
        ZStack(alignment: .top) {
           

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                  

                if isLoading {
                    ProgressView("加载中...".localized)
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if songs.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "music.note")
                            .font(.system(size: 36))
                            .foregroundStyle(.tertiary)
                        Text("歌单暂无歌曲".localized)
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 200)
                } else {
                   

                   

                    // Song list
                    LazyVStack(spacing: 0) {
                        ForEach(Array(songs.enumerated()), id: \.element.id) { idx, song in
                            UnifiedSongRow(song: song, index: idx + 1, allSongs: songs)
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
                                Text("标题".localized).frame(maxWidth: .infinity, alignment: .leading)
                                Text("艺人".localized).frame(width: 160, alignment: .leading)
                                Text("专辑".localized).frame(width: 160, alignment: .leading)
                                Image(systemName: "clock").frame(width: 60, alignment: .trailing)
                            }
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 6)
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
            
                .foregroundStyle(themeManager.accentColor)
                .padding(8)
                .background(themeManager.tintColor, in: Circle())

            }
            .padding(.horizontal , 6)
            .buttonStyle(.plain)
            .keyboardShortcut("[", modifiers: [.command])
            .help("返回 (⌘[)".localized)


        
        
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
                Text("歌单".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Text(playlist?.name ?? "歌单".localized)
                    .font(.title.bold())
                    .lineLimit(2)

                if let desc = playlist?.description, !desc.isEmpty {
                    Text(desc)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }

                if let count = playlist?.trackCount {
                    Text(String(format: "%d 首歌曲".localized, count))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()

                // Play all + count
                PlaybackActionBar(songs: songs, downloadHelpText: "下载此歌单中的全部歌曲到本地".localized)
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

#Preview {
    PlaylistDetailView(playlistId: 1)
        .environment(PlayerManager())
        .environment(ThemeManager.shared)
        .frame(height: 800)
}
