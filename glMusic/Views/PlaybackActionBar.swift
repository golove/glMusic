//
//  PlaybackActionBar.swift
//  glMusic
//
//  Created by go love on 11/2/26.
//

import SwiftUI

/// 统一的播放操作栏（播放、随机播放、下载全部）
struct PlaybackActionBar: View {
    let songs: [APISong]
    var playTitle: String = "播放"
    var shuffleTitle: String = "随机播放"
    var downloadTitle: String = "下载全部"
    var showDownloadAll: Bool = true
    var downloadHelpText: String = "下载全部歌曲到本地"
    @Environment(PlayerManager.self) private var player

    var body: some View {
        HStack(spacing: 12) {
            Button {
                player.playAll(songs)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 12))
                    Text(playTitle)
                        .font(.system(size: 13, weight: .semibold))
                }
                .padding(.horizontal, 18)
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
                    Text(shuffleTitle)
                        .font(.system(size: 13, weight: .medium))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.quaternary, in: Capsule())
                .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)

            if showDownloadAll {
                Button {
                    DownloadManager.shared.downloadAll(songs)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: 12))
                        Text(downloadTitle)
                            .font(.system(size: 13, weight: .medium))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.quaternary, in: Capsule())
                    .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
                .help(downloadHelpText)
            }

            Spacer()
        }
    }
}
