//
//  CustomPlaylistManager.swift
//  glMusic
//
//  Created by go love on 11/10/26.
//

import Foundation
import SwiftUI
import NeteaseCloudMusicAPI

struct CustomPlaylist: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var description: String
    var coverUrl: String?
    var createdAt: Date
    var updatedAt: Date
    var songs: [APISong]

    var trackCount: Int { songs.count }
    var durationMs: Int { songs.reduce(0) { $0 + $1.durationMs } }

    var durationText: String {
        let totalSec = durationMs / 1000
        let min = totalSec / 60
        let sec = totalSec % 60
        if min >= 60 {
            let hr = min / 60
            let remainMin = min % 60
            return "\(hr) 小时 \(remainMin) 分钟"
        }
        return "\(min) 分钟 \(sec) 秒"
    }
}

@MainActor
@Observable
final class CustomPlaylistManager {
    static let shared = CustomPlaylistManager()

    var playlists: [CustomPlaylist] = [] {
        didSet {
            rebuildSongIdCache()
        }
    }
    private var songIdCache: [String: Set<Int>] = [:]
    private var saveTask: Task<Void, Never>?

    private var storageFileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("glMusic", isDirectory: true)
        if !FileManager.default.fileExists(atPath: appDir.path) {
            try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        }
        return appDir.appendingPathComponent("custom_playlists.json")
    }

    private init() {
        loadFromDisk()
    }

    // MARK: - CRUD

    @discardableResult
    func createPlaylist(name: String, description: String = "") -> CustomPlaylist {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = trimmed.isEmpty ? "新建歌单" : trimmed
        let playlist = CustomPlaylist(
            id: UUID().uuidString,
            name: finalName,
            description: description,
            coverUrl: nil,
            createdAt: Date(),
            updatedAt: Date(),
            songs: []
        )
        playlists.insert(playlist, at: 0)
        scheduleSave()
        return playlist
    }

    func deletePlaylist(id: String) {
        playlists.removeAll { $0.id == id }
        scheduleSave()
    }

    func renamePlaylist(id: String, newName: String, newDescription: String? = nil) {
        guard let idx = playlists.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            playlists[idx].name = trimmed
        }
        if let desc = newDescription {
            playlists[idx].description = desc
        }
        playlists[idx].updatedAt = Date()
        scheduleSave()
    }

    func addSong(_ song: APISong, toPlaylistId id: String) {
        guard let idx = playlists.firstIndex(where: { $0.id == id }) else { return }
        if !playlists[idx].songs.contains(where: { $0.id == song.id }) {
            playlists[idx].songs.append(song)
            playlists[idx].updatedAt = Date()
            if playlists[idx].coverUrl == nil, let cover = song.coverUrl, !cover.isEmpty {
                playlists[idx].coverUrl = cover
            }
            scheduleSave()
        }
    }

    func removeSong(songId: Int, fromPlaylistId id: String) {
        guard let idx = playlists.firstIndex(where: { $0.id == id }) else { return }
        playlists[idx].songs.removeAll { $0.id == songId }
        playlists[idx].updatedAt = Date()
        scheduleSave()
    }

    private func rebuildSongIdCache() {
        var dict: [String: Set<Int>] = [:]
        for pl in playlists {
            dict[pl.id] = Set(pl.songs.map(\.id))
        }
        self.songIdCache = dict
    }

    func isSongInPlaylist(songId: Int, playlistId: String) -> Bool {
        if let set = songIdCache[playlistId] {
            return set.contains(songId)
        }
        guard let pl = playlists.first(where: { $0.id == playlistId }) else { return false }
        return pl.songs.contains(where: { $0.id == songId })
    }

    func playlist(withId id: String) -> CustomPlaylist? {
        playlists.first { $0.id == id }
    }

    // MARK: - Persistence

    private func scheduleSave() {
        saveTask?.cancel()
        let items = self.playlists
        let fileURL = self.storageFileURL
        saveTask = Task.detached(priority: .background) {
            guard !Task.isCancelled else { return }
            do {
                let data = try JSONEncoder().encode(items)
                try data.write(to: fileURL, options: .atomic)
            } catch {
                print("❌ [glMusic] 保存自建歌单失败: \(error)")
            }
        }
    }

    private func loadFromDisk() {
        let fileURL = storageFileURL
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            let items = try JSONDecoder().decode([CustomPlaylist].self, from: data)
            self.playlists = items
        } catch {
            print("⚠️ [glMusic] 读取自建歌单失败或文件为空: \(error)")
        }
    }
}
