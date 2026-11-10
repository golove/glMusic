//
//  AddToPlaylistMenu.swift
//  glMusic
//
//  Created by go love on 11/10/26.
//

import SwiftUI
import NeteaseCloudMusicAPI

/// 通用「添加到歌单」上下文二级菜单组件
struct AddToPlaylistMenu: View {
    let song: APISong
    private var playlistManager = CustomPlaylistManager.shared

    var body: some View {
        Menu {
            if playlistManager.playlists.isEmpty {
                Button {
                    let pl = playlistManager.createPlaylist(name: "新建歌单".localized)
                    playlistManager.addSong(song, toPlaylistId: pl.id)
                } label: {
                    Label("新建歌单并添加".localized, systemImage: "plus")
                }
            } else {
                Button {
                    let count = playlistManager.playlists.count + 1
                    let defaultName = String(format: "%@ %d", "我的歌单".localized, count)
                    let pl = playlistManager.createPlaylist(name: defaultName)
                    playlistManager.addSong(song, toPlaylistId: pl.id)
                } label: {
                    Label("新建歌单并添加...".localized, systemImage: "plus")
                }

                Divider()

                ForEach(playlistManager.playlists) { pl in
                    Button {
                        if playlistManager.isSongInPlaylist(songId: song.id, playlistId: pl.id) {
                            playlistManager.removeSong(songId: song.id, fromPlaylistId: pl.id)
                        } else {
                            playlistManager.addSong(song, toPlaylistId: pl.id)
                        }
                    } label: {
                        HStack {
                            Text(pl.name)
                            if playlistManager.isSongInPlaylist(songId: song.id, playlistId: pl.id) {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
        } label: {
            Label("添加到歌单".localized, systemImage: "folder.badge.plus")
        }
    }
}
