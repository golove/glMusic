//
//  DownloadManager.swift
//  glMusic
//
//  Created by go love on 10/29/26.
//

import Foundation
import SwiftUI
import AppKit

// MARK: - Downloaded Song Model

struct DownloadedSong: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let artist: String
    let album: String
    let coverUrl: String?
    let durationMs: Int
    let fileName: String
    let localCoverName: String?
    let localLyricName: String?
    var fileSize: Int64
    let downloadedAt: Date

    var displayArtist: String { artist }
    var displayAlbum: String { album }
    var durationText: String {
        let s = durationMs / 1000
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    var fileSizeText: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }

    /// 转换为 APISong 供 PlayerManager 直接无缝播放
    var asAPISong: APISong {
        APISong(
            id: id,
            name: name,
            ar: [APIArtistBrief(id: 0, name: artist, picUrl: nil)],
            al: APIAlbumBrief(id: 0, name: album, picUrl: coverUrl),
            dt: durationMs
        )
    }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: DownloadedSong, rhs: DownloadedSong) -> Bool { lhs.id == rhs.id }
}

// MARK: - Download Status

enum DownloadStatus: Equatable {
    case notDownloaded
    case waiting
    case downloading(progress: Double)
    case downloaded
    case failed(error: String)
}

// MARK: - Download Manager

@Observable
final class DownloadManager: NSObject, @unchecked Sendable {
    static let shared = DownloadManager()

    // MARK: - State

    var downloadedSongs: [DownloadedSong] = [] {
        didSet {
            downloadedSongIds = Set(downloadedSongs.map(\.id))
        }
    }
    /// 内存缓存已下载 ID 集合，加速 isDownloaded 频繁查询 (O(1) 替代文件系统 I/O)
    private(set) var downloadedSongIds: Set<Int> = []
    var activeDownloads: [Int: Double] = [:]       // songId -> progress (0.0 ... 1.0)
    var downloadErrors: [Int: String] = [:]       // songId -> errorMessage

    // MARK: - Concurrency & Queue Management

    private let maxConcurrentDownloads = 3
    private var waitingQueue: [APISong] = []
    private var activeTaskCount: Int = 0

    // MARK: - Internal Tasks & Metadata

    private var urlSession: URLSession!
    private let lock = NSLock()
    private var downloadTasks: [Int: URLSessionDownloadTask] = [:]
    private var pendingItems: [Int: (song: DownloadedSong, destination: URL)] = [:]

    // MARK: - Directory Paths

    /// 沙盒内持久化下载目录 (Documents/Downloads)，启动时初始化一次避免重复 I/O
    let downloadsDirectory: URL

    private var metadataFileURL: URL {
        downloadsDirectory.appendingPathComponent("downloads_metadata.json")
    }

    // MARK: - Init

    override init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dir = docs.appendingPathComponent("Downloads", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
        }
        self.downloadsDirectory = dir

        super.init()

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 45
        config.timeoutIntervalForResource = 600
        self.urlSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        loadSavedMetadata()
    }

    // MARK: - Queries

    /// 极速内存查询已下载状态，无文件系统阻塞
    func isDownloaded(_ songId: Int) -> Bool {
        downloadedSongIds.contains(songId)
    }

    func isDownloading(_ songId: Int) -> Bool {
        activeDownloads[songId] != nil || isWaiting(songId)
    }

    func isWaiting(_ songId: Int) -> Bool {
        lock.withLock {
            waitingQueue.contains(where: { $0.id == songId })
        }
    }

    func downloadProgress(_ songId: Int) -> Double? {
        activeDownloads[songId]
    }

    func downloadStatus(_ songId: Int) -> DownloadStatus {
        if isDownloaded(songId) {
            return .downloaded
        }
        if let prog = activeDownloads[songId] {
            return .downloading(progress: prog)
        }
        if isWaiting(songId) {
            return .waiting
        }
        if let err = downloadErrors[songId] {
            return .failed(error: err)
        }
        return .notDownloaded
    }

    /// 获取本地已下载的音频文件路径 (存在则返回，用于 PlayerManager 离线播放)
    func localAudioURL(for songId: Int) -> URL? {
        guard let song = downloadedSongs.first(where: { $0.id == songId }) else { return nil }
        let fileURL = downloadsDirectory.appendingPathComponent(song.fileName)
        return FileManager.default.fileExists(atPath: fileURL.path) ? fileURL : nil
    }

    /// 获取本地已下载的歌词文本 (存在则返回)
    func localLyrics(for songId: Int) -> String? {
        guard let song = downloadedSongs.first(where: { $0.id == songId }),
              let lrcName = song.localLyricName else { return nil }
        let lrcURL = downloadsDirectory.appendingPathComponent(lrcName)
        return try? String(contentsOf: lrcURL, encoding: .utf8)
    }

    /// 获取本地已下载的歌词翻译文本 (存在则返回)
    func localTranslation(for songId: Int) -> String? {
        let transURL = downloadsDirectory.appendingPathComponent("\(songId)_trans.lrc")
        return try? String(contentsOf: transURL, encoding: .utf8)
    }

    /// 获取本地已下载的封面图片路径
    func localCoverURL(for songId: Int) -> URL? {
        guard let song = downloadedSongs.first(where: { $0.id == songId }),
              let coverName = song.localCoverName else { return nil }
        let coverURL = downloadsDirectory.appendingPathComponent(coverName)
        return FileManager.default.fileExists(atPath: coverURL.path) ? coverURL : nil
    }

    var totalDiskSpaceText: String {
        let total = downloadedSongs.reduce(Int64(0)) { $0 + $1.fileSize }
        return ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
    }

    // MARK: - Download Operations & Queue Control

    func downloadSong(_ song: APISong) {
        if isDownloaded(song.id) || isDownloading(song.id) { return }

        lock.withLock {
            if !waitingQueue.contains(where: { $0.id == song.id }) {
                waitingQueue.append(song)
            }
        }
        processQueue()
    }

    func downloadAll(_ songs: [APISong]) {
        let toQueue = songs.filter { !isDownloaded($0.id) && !isDownloading($0.id) }
        guard !toQueue.isEmpty else { return }

        lock.withLock {
            for song in toQueue {
                if !waitingQueue.contains(where: { $0.id == song.id }) {
                    waitingQueue.append(song)
                }
            }
        }
        processQueue()
    }

    private func processQueue() {
        var nextSong: APISong? = nil
        lock.withLock {
            if activeTaskCount < maxConcurrentDownloads && !waitingQueue.isEmpty {
                nextSong = waitingQueue.removeFirst()
                activeTaskCount += 1
            }
        }

        guard let song = nextSong else { return }

        DispatchQueue.main.async {
            self.activeDownloads[song.id] = 0.02
            self.downloadErrors.removeValue(forKey: song.id)
        }

        Task {
            await startDownloadTask(for: song)
        }
    }

    private func finishActiveTask(for songId: Int) {
        lock.withLock {
            activeTaskCount = max(0, activeTaskCount - 1)
        }
        processQueue()
    }

    private func startDownloadTask(for song: APISong) async {
        do {
            // 1. 获取音频 URL（优先最高品质 lossless → exhigh → standard，灰色歌曲 Unblock 匹配）
            var urlStr = try await NetworkManager.shared.songURL(id: song.id, level: "lossless")
            if urlStr == nil || urlStr?.isEmpty == true {
                urlStr = try await NetworkManager.shared.songURL(id: song.id, level: "exhigh")
            }
            if urlStr == nil || urlStr?.isEmpty == true {
                urlStr = try await NetworkManager.shared.songURL(id: song.id, level: "standard")
            }
            if urlStr == nil || urlStr?.isEmpty == true {
                urlStr = try await NetworkManager.shared.songURLMatch(id: song.id)
            }

            guard let finalUrl = urlStr, !finalUrl.isEmpty,
                  let remoteAudioURL = URL(string: finalUrl) else {
                throw NSError(domain: "DownloadManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法获取可下载的音频播放源"])
            }

            // 2. 推断音频文件扩展名
            let ext = remoteAudioURL.pathExtension.isEmpty ? "mp3" : remoteAudioURL.pathExtension
            let safeTitle = sanitizeFileName("\(song.id)_\(song.name) - \(song.displayArtist)")
            let audioFileName = "\(safeTitle).\(ext)"
            let audioDestination = downloadsDirectory.appendingPathComponent(audioFileName)

            // 3. 异步下载歌词并保存为本地 .lrc 文件
            var lyricFileName: String? = nil
            if let lyricResp = try? await NetworkManager.shared.lyrics(id: song.id),
               let lrcText = lyricResp.lrc?.lyric, !lrcText.isEmpty {
                let lrcName = "\(song.id)_\(sanitizeFileName(song.name)).lrc"
                let lrcURL = downloadsDirectory.appendingPathComponent(lrcName)
                try? lrcText.write(to: lrcURL, atomically: true, encoding: .utf8)
                lyricFileName = lrcName

                // 若有双语翻译歌词，一并保存
                if let transText = lyricResp.tlyric?.lyric, !transText.isEmpty {
                    let transURL = downloadsDirectory.appendingPathComponent("\(song.id)_trans.lrc")
                    try? transText.write(to: transURL, atomically: true, encoding: .utf8)
                }
            }

            // 4. 异步下载封面并保存为本地图片
            var coverFileName: String? = nil
            if let coverUrlStr = song.coverUrl, let coverRemoteURL = URL(string: coverUrlStr) {
                if let (coverData, _) = try? await URLSession.shared.data(from: coverRemoteURL) {
                    let covName = "\(song.id)_cover.jpg"
                    let covURL = downloadsDirectory.appendingPathComponent(covName)
                    try? coverData.write(to: covURL)
                    coverFileName = covName
                }
            }

            // 5. 构建元数据模型
            let downloadedSong = DownloadedSong(
                id: song.id,
                name: song.name,
                artist: song.displayArtist,
                album: song.displayAlbum,
                coverUrl: song.coverUrl,
                durationMs: song.durationMs,
                fileName: audioFileName,
                localCoverName: coverFileName,
                localLyricName: lyricFileName,
                fileSize: 0,
                downloadedAt: Date()
            )

            // 6. 创建后台下载任务
            let task = urlSession.downloadTask(with: remoteAudioURL)
            task.taskDescription = "\(song.id)"

            lock.withLock {
                pendingItems[song.id] = (downloadedSong, audioDestination)
                downloadTasks[song.id] = task
            }

            task.resume()
        } catch {
            await MainActor.run {
                self.activeDownloads.removeValue(forKey: song.id)
                self.downloadErrors[song.id] = error.localizedDescription
            }
            finishActiveTask(for: song.id)
        }
    }

    func cancelDownload(_ songId: Int) {
        lock.withLock {
            waitingQueue.removeAll(where: { $0.id == songId })
        }
        let task = lock.withLock { () -> URLSessionDownloadTask? in
            pendingItems.removeValue(forKey: songId)
            return downloadTasks.removeValue(forKey: songId)
        }
        task?.cancel()
        DispatchQueue.main.async {
            self.activeDownloads.removeValue(forKey: songId)
            self.downloadErrors.removeValue(forKey: songId)
        }
        finishActiveTask(for: songId)
    }

    // MARK: - Deletion & Management

    func deleteDownload(_ songId: Int) {
        if let idx = downloadedSongs.firstIndex(where: { $0.id == songId }) {
            let song = downloadedSongs[idx]
            // 删除音频
            let audioURL = downloadsDirectory.appendingPathComponent(song.fileName)
            try? FileManager.default.removeItem(at: audioURL)
            // 删除歌词及翻译
            if let lrc = song.localLyricName {
                try? FileManager.default.removeItem(at: downloadsDirectory.appendingPathComponent(lrc))
                try? FileManager.default.removeItem(at: downloadsDirectory.appendingPathComponent("\(song.id)_trans.lrc"))
            }
            // 删除封面
            if let cov = song.localCoverName {
                try? FileManager.default.removeItem(at: downloadsDirectory.appendingPathComponent(cov))
            }
            downloadedSongs.remove(at: idx)
            saveMetadata()
        }
    }

    func clearAllDownloads() {
        for song in downloadedSongs {
            let audioURL = downloadsDirectory.appendingPathComponent(song.fileName)
            try? FileManager.default.removeItem(at: audioURL)
            if let lrc = song.localLyricName {
                try? FileManager.default.removeItem(at: downloadsDirectory.appendingPathComponent(lrc))
                try? FileManager.default.removeItem(at: downloadsDirectory.appendingPathComponent("\(song.id)_trans.lrc"))
            }
            if let cov = song.localCoverName {
                try? FileManager.default.removeItem(at: downloadsDirectory.appendingPathComponent(cov))
            }
        }
        downloadedSongs.removeAll()
        saveMetadata()
    }

    func revealInFinder(_ songId: Int) {
        if let song = downloadedSongs.first(where: { $0.id == songId }) {
            let fileURL = downloadsDirectory.appendingPathComponent(song.fileName)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                NSWorkspace.shared.activateFileViewerSelecting([fileURL])
                return
            }
        }
        openDownloadsFolder()
    }

    func openDownloadsFolder() {
        NSWorkspace.shared.open(downloadsDirectory)
    }

    // MARK: - Persistence

    private func loadSavedMetadata() {
        guard FileManager.default.fileExists(atPath: metadataFileURL.path),
              let data = try? Data(contentsOf: metadataFileURL),
              let items = try? JSONDecoder().decode([DownloadedSong].self, from: data) else {
            return
        }

        // 过滤掉磁盘上已被删除的遗留项
        self.downloadedSongs = items.filter { song in
            let path = downloadsDirectory.appendingPathComponent(song.fileName).path
            return FileManager.default.fileExists(atPath: path)
        }
    }

    private func saveMetadata() {
        if let data = try? JSONEncoder().encode(downloadedSongs) {
            try? data.write(to: metadataFileURL, options: .atomic)
        }
    }

    private func sanitizeFileName(_ name: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        let cleaned = name.components(separatedBy: invalid).joined(separator: "_")
        let trimmed = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count > 100 {
            return String(trimmed.prefix(100))
        }
        return trimmed.isEmpty ? "song" : trimmed
    }
}

// MARK: - URLSessionDownloadDelegate

extension DownloadManager: URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let idStr = downloadTask.taskDescription, let songId = Int(idStr) else { return }
        let progress: Double
        if totalBytesExpectedToWrite > 0 {
            progress = min(max(Double(totalBytesWritten) / Double(totalBytesExpectedToWrite), 0.05), 0.99)
        } else {
            progress = 0.5
        }

        DispatchQueue.main.async {
            self.activeDownloads[songId] = progress
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let idStr = downloadTask.taskDescription, let songId = Int(idStr) else { return }

        // 1. 线程安全地同步取出待处理项
        let item: (song: DownloadedSong, destination: URL)? = lock.withLock {
            _ = downloadTasks.removeValue(forKey: songId)
            return pendingItems.removeValue(forKey: songId)
        }

        guard let item else {
            print("⚠️ 未找到 songId=\(songId) 的待保存下载信息")
            finishActiveTask(for: songId)
            return
        }
        var song = item.song
        let destination = item.destination

        // 2. 同步完成文件持久化移动，防止临时文件被系统回收
        do {
            let targetDir = destination.deletingLastPathComponent()
            if !FileManager.default.fileExists(atPath: targetDir.path) {
                try FileManager.default.createDirectory(at: targetDir, withIntermediateDirectories: true, attributes: nil)
            }

            if FileManager.default.fileExists(atPath: destination.path) {
                try? FileManager.default.removeItem(at: destination)
            }

            do {
                try FileManager.default.moveItem(at: location, to: destination)
            } catch {
                try FileManager.default.copyItem(at: location, to: destination)
            }

            let attrs = try FileManager.default.attributesOfItem(atPath: destination.path)
            let fileSize = (attrs[.size] as? Int64) ?? 0
            song.fileSize = fileSize

            // 3. 在主线程更新 UI 响应式状态与持久化元数据
            DispatchQueue.main.async {
                self.downloadedSongs.removeAll(where: { $0.id == songId })
                self.downloadedSongs.insert(song, at: 0)
                self.saveMetadata()
                self.activeDownloads.removeValue(forKey: songId)
                self.downloadErrors.removeValue(forKey: songId)
                print("✅ 歌曲已成功下载至: \(destination.lastPathComponent) (\(song.fileSizeText))")
            }
        } catch {
            print("❌ 移动已下载音频失败: \(error)")
            DispatchQueue.main.async {
                self.activeDownloads.removeValue(forKey: songId)
                self.downloadErrors[songId] = error.localizedDescription
            }
        }

        finishActiveTask(for: songId)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let idStr = task.taskDescription, let songId = Int(idStr) else { return }

        lock.withLock {
            _ = pendingItems.removeValue(forKey: songId)
            _ = downloadTasks.removeValue(forKey: songId)
        }

        if let error = error, (error as NSError).code != NSURLErrorCancelled {
            DispatchQueue.main.async {
                self.activeDownloads.removeValue(forKey: songId)
                self.downloadErrors[songId] = error.localizedDescription
                print("❌ 下载任务出错: \(error)")
            }
        }

        finishActiveTask(for: songId)
    }
}
