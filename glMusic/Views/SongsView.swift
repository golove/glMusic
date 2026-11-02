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
    @State private var chartName = "热歌榜"

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(songs.enumerated()), id: \.element.id) { idx, song in
                        UnifiedSongRow(song: song, index: idx + 1, allSongs: songs)
                    }
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                // Header
                VStack(alignment: .leading) {
                    VStack(alignment: .leading) {
                        Text("歌曲")
                            .font(.largeTitle.bold())
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
                            PlaybackActionBar(songs: songs)
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

//                        Divider().padding(.horizontal, 24)
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

#Preview {
    SongsView()
        .environment(PlayerManager())
}
