//
//  DownloadManager.swift
//  glMusic
//
//  Created by go love on 10/29/26.
//

import Foundation
import SwiftUI
import AppKit
import AVFoundation
import UniformTypeIdentifiers

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
    var isLocalImport: Bool? = false

    var isLocal: Bool {
        isLocalImport == true || id < 0
    }

    var sourceBadgeText: String {
        isLocal ? "本地" : "已下载"
    }

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

@MainActor
@Observable
final class DownloadManager: NSObject {
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
    var isImporting: Bool = false
    var importStatusMessage: String? = nil

    var localImportedCount: Int {
        downloadedSongs.filter(\.isLocal).count
    }

    var remoteDownloadedCount: Int {
        downloadedSongs.filter { !$0.isLocal }.count
    }

    // MARK: - Concurrency & Queue Management

    private let maxConcurrentDownloads = 3
    private var waitingQueue: [APISong] = []
    private var waitingSongIds: Set<Int> = []
    private var activeSongIds: Set<Int> = []

    // MARK: - Internal Tasks & Metadata

    private var urlSession: URLSession!
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
        waitingSongIds.contains(songId)
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

        if !waitingSongIds.contains(song.id) {
            waitingQueue.append(song)
            waitingSongIds.insert(song.id)
        }
        processQueue()
    }

    func downloadAll(_ songs: [APISong]) {
        let toQueue = songs.filter { !isDownloaded($0.id) && !isDownloading($0.id) }
        guard !toQueue.isEmpty else { return }

        for song in toQueue {
            if !waitingSongIds.contains(song.id) {
                waitingQueue.append(song)
                waitingSongIds.insert(song.id)
            }
        }
        processQueue()
    }

    private func processQueue() {
        while activeSongIds.count < maxConcurrentDownloads && !waitingQueue.isEmpty {
            let song = waitingQueue.removeFirst()
            waitingSongIds.remove(song.id)
            activeSongIds.insert(song.id)

            self.activeDownloads[song.id] = 0.02
            self.downloadErrors.removeValue(forKey: song.id)

            Task {
                await startDownloadTask(for: song)
            }
        }
    }

    private func finishActiveTask(for songId: Int) {
        guard activeSongIds.remove(songId) != nil else { return }
        pendingItems.removeValue(forKey: songId)
        downloadTasks.removeValue(forKey: songId)
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

            // 检查在此异步网络阶段是否已被用户取消
            guard activeSongIds.contains(song.id) else { return }

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

            // 再次检查在此异步网络阶段是否已被用户取消
            guard activeSongIds.contains(song.id) else { return }

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

            pendingItems[song.id] = (downloadedSong, audioDestination)
            downloadTasks[song.id] = task

            task.resume()
        } catch {
            self.activeDownloads.removeValue(forKey: song.id)
            self.downloadErrors[song.id] = error.localizedDescription
            finishActiveTask(for: song.id)
        }
    }

    func cancelDownload(_ songId: Int) {
        waitingQueue.removeAll(where: { $0.id == songId })
        waitingSongIds.remove(songId)

        let task = downloadTasks.removeValue(forKey: songId)
        pendingItems.removeValue(forKey: songId)
        task?.cancel()

        activeDownloads.removeValue(forKey: songId)
        downloadErrors.removeValue(forKey: songId)
        finishActiveTask(for: songId)
    }

    // MARK: - Deletion & Management

    func deleteDownload(_ songId: Int) {
        if let idx = downloadedSongs.firstIndex(where: { $0.id == songId }) {
            guard downloadedSongs.indices.contains(idx) else { return }
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
        let songs = downloadedSongs
        let targetURL = metadataFileURL
        Task.detached(priority: .background) {
            if let data = try? JSONEncoder().encode(songs) {
                try? data.write(to: targetURL, options: .atomic)
            }
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

    // MARK: - Local Song Import (本地音乐导入)

    /// 弹出系统原生文件/目录选择器导入本地音频
    @MainActor
    func openFilePickerToImport() {
        let panel = NSOpenPanel()
        panel.title = "选择本地音频文件或文件夹"
        panel.message = "支持导入 MP3、FLAC、M4A、WAV、AAC、AIFF、ALAC、OGG 等音频格式"
        panel.prompt = "导入"
        panel.allowsMultipleSelection = true
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowedContentTypes = [
            .audio,
            .mp3,
            UTType(filenameExtension: "flac") ?? .audio,
            UTType(filenameExtension: "m4a") ?? .audio,
            UTType(filenameExtension: "wav") ?? .audio,
            UTType(filenameExtension: "aac") ?? .audio,
            UTType(filenameExtension: "aiff") ?? .audio,
            UTType(filenameExtension: "ogg") ?? .audio
        ]

        panel.begin { [weak self] response in
            guard response == .OK else { return }
            let urls = panel.urls
            guard !urls.isEmpty else { return }

            Task { @MainActor [weak self] in
                await self?.importLocalSongs(from: urls)
            }
        }
    }

    private struct LocalMetadata {
        var title: String
        var artist: String
        var album: String
        var durationMs: Int
        var artworkData: Data?
        var lyricText: String?
    }

    /// 递归扫描并导入选中的音频文件或文件夹
    @discardableResult
    func importLocalSongs(from urls: [URL]) async -> (imported: Int, skipped: Int, failed: Int) {
        let audioFiles = collectAudioFiles(from: urls)
        guard !audioFiles.isEmpty else {
            importStatusMessage = "未发现支持的音频文件"
            Task {
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                self.importStatusMessage = nil
            }
            return (0, 0, 0)
        }

        isImporting = true
        var importedCount = 0
        var skippedCount = 0
        var failedCount = 0
        var newlyImported: [DownloadedSong] = []

        for (index, fileURL) in audioFiles.enumerated() {
            importStatusMessage = "正在导入 (\(index + 1)/\(audioFiles.count)): \(fileURL.lastPathComponent)"

            let meta = await extractMetadata(from: fileURL)
            let ext = fileURL.pathExtension.isEmpty ? "mp3" : fileURL.pathExtension.lowercased()
            let safeTitle = sanitizeFileName(meta.title)
            let safeArtist = sanitizeFileName(meta.artist)

            // 生成确定性的负数本地 ID
            let baseIdentifier = "\(fileURL.lastPathComponent)_\(meta.durationMs)"
            var songId = generateLocalSongId(for: baseIdentifier)
            let candidateFileName = "local_\(abs(songId))_\(safeTitle) - \(safeArtist).\(ext)"

            // 检查是否已存在同名或同名文件的歌曲
            if downloadedSongs.contains(where: {
                $0.fileName == candidateFileName ||
                ($0.name == meta.title && $0.artist == meta.artist && abs($0.durationMs - meta.durationMs) < 1000)
            }) {
                skippedCount += 1
                continue
            }

            // 确保 ID 在集合中绝对唯一
            while downloadedSongIds.contains(songId) && downloadedSongs.first(where: { $0.id == songId })?.fileName != candidateFileName {
                songId -= 1
            }

            let audioFileName = "local_\(abs(songId))_\(safeTitle) - \(safeArtist).\(ext)"
            let targetAudioURL = downloadsDirectory.appendingPathComponent(audioFileName)

            do {
                // 复制音频文件到沙盒目录 (如果原本就在沙盒目录则跳过复制)
                if fileURL.standardizedFileURL != targetAudioURL.standardizedFileURL {
                    if FileManager.default.fileExists(atPath: targetAudioURL.path) {
                        try? FileManager.default.removeItem(at: targetAudioURL)
                    }
                    try FileManager.default.copyItem(at: fileURL, to: targetAudioURL)
                }

                // 保存内嵌封面
                var coverFileName: String? = nil
                var coverURLString: String? = nil
                if let artData = meta.artworkData {
                    let covName = "local_\(abs(songId))_cover.jpg"
                    let targetCoverURL = downloadsDirectory.appendingPathComponent(covName)
                    try? artData.write(to: targetCoverURL)
                    coverFileName = covName
                    coverURLString = targetCoverURL.absoluteString
                }

                // 保存伴生歌词
                var lyricFileName: String? = nil
                if let lrc = meta.lyricText, !lrc.isEmpty {
                    let lrcName = "local_\(abs(songId))_\(safeTitle).lrc"
                    let targetLrcURL = downloadsDirectory.appendingPathComponent(lrcName)
                    try? lrc.write(to: targetLrcURL, atomically: true, encoding: .utf8)
                    lyricFileName = lrcName
                }

                let attrs = try? FileManager.default.attributesOfItem(atPath: targetAudioURL.path)
                let fileSize = (attrs?[.size] as? Int64) ?? 0

                let downloadedSong = DownloadedSong(
                    id: songId,
                    name: meta.title,
                    artist: meta.artist,
                    album: meta.album,
                    coverUrl: coverURLString,
                    durationMs: meta.durationMs,
                    fileName: audioFileName,
                    localCoverName: coverFileName,
                    localLyricName: lyricFileName,
                    fileSize: fileSize,
                    downloadedAt: Date(),
                    isLocalImport: true
                )

                newlyImported.append(downloadedSong)
                importedCount += 1
            } catch {
                print("❌ 导入本地音频失败 (\(fileURL.lastPathComponent)): \(error)")
                failedCount += 1
            }
        }

        if !newlyImported.isEmpty {
            for song in newlyImported {
                downloadedSongs.removeAll(where: { $0.id == song.id || $0.fileName == song.fileName })
                downloadedSongs.insert(song, at: 0)
                downloadedSongIds.insert(song.id)
            }
            saveMetadata()
        }

        isImporting = false

        if importedCount > 0 {
            var msg = "成功导入 \(importedCount) 首本地歌曲"
            if skippedCount > 0 {
                msg += "（跳过 \(skippedCount) 首已存在）"
            }
            importStatusMessage = msg
        } else if skippedCount > 0 {
            importStatusMessage = "所选歌曲均已导入（跳过 \(skippedCount) 首）"
        } else {
            importStatusMessage = "未成功导入歌曲"
        }

        Task {
            try? await Task.sleep(nanoseconds: 3_500_000_000)
            self.importStatusMessage = nil
        }

        return (importedCount, skippedCount, failedCount)
    }

    /// 递归扫描目录，收集所有支持的本地音频文件
    private func collectAudioFiles(from urls: [URL]) -> [URL] {
        let supportedExtensions: Set<String> = [
            "mp3", "m4a", "flac", "wav", "aac", "aiff", "aif", "alac", "ogg"
        ]
        var result: [URL] = []
        let fm = FileManager.default

        for url in urls {
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: url.path, isDirectory: &isDir) {
                if isDir.boolValue {
                    if let enumerator = fm.enumerator(
                        at: url,
                        includingPropertiesForKeys: [.isRegularFileKey],
                        options: [.skipsHiddenFiles, .skipsPackageDescendants]
                    ) {
                        for case let fileURL as URL in enumerator {
                            if supportedExtensions.contains(fileURL.pathExtension.lowercased()) {
                                result.append(fileURL)
                            }
                        }
                    }
                } else {
                    if supportedExtensions.contains(url.pathExtension.lowercased()) {
                        result.append(url)
                    }
                }
            }
        }
        return result
    }

    /// 提取音频文件的元数据、时长、封面与伴生歌词
    private func extractMetadata(from fileURL: URL) async -> LocalMetadata {
        let asset = AVURLAsset(url: fileURL)
        let filename = fileURL.deletingPathExtension().lastPathComponent

        var title: String?
        var artist: String?
        var album: String?
        var durationMs: Int = 0
        var artworkData: Data?
        var lyricText: String?

        // 1. 读取音频时长
        if let dur = try? await asset.load(.duration) {
            let seconds = CMTimeGetSeconds(dur)
            if seconds.isFinite && seconds > 0 {
                durationMs = Int(seconds * 1000)
            }
        }

        // 2. 读取通用元数据 (CommonMetadata)
        if let common = try? await asset.load(.commonMetadata) {
            for item in common {
                guard let key = item.commonKey?.rawValue else { continue }
                switch key {
                case "title":
                    if let val = try? await item.load(.stringValue), !val.trimmingCharacters(in: .whitespaces).isEmpty {
                        title = val.trimmingCharacters(in: .whitespaces)
                    }
                case "artist":
                    if let val = try? await item.load(.stringValue), !val.trimmingCharacters(in: .whitespaces).isEmpty {
                        artist = val.trimmingCharacters(in: .whitespaces)
                    }
                case "albumName":
                    if let val = try? await item.load(.stringValue), !val.trimmingCharacters(in: .whitespaces).isEmpty {
                        album = val.trimmingCharacters(in: .whitespaces)
                    }
                case "artwork":
                    if let data = try? await item.load(.dataValue) {
                        artworkData = data
                    }
                default:
                    break
                }
            }
        }

        // 3. 读取格式特定元数据 (ID3 / iTunes / FLAC)
        if let formats = try? await asset.load(.availableMetadataFormats) {
            for format in formats {
                if let items = try? await asset.loadMetadata(for: format) {
                    for item in items {
                        if title == nil {
                            if item.identifier == .id3MetadataTitleDescription || item.identifier == .iTunesMetadataSongName {
                                if let val = try? await item.load(.stringValue), !val.isEmpty {
                                    title = val.trimmingCharacters(in: .whitespaces)
                                }
                            }
                        }
                        if artist == nil {
                            if item.identifier == .id3MetadataLeadPerformer || item.identifier == .iTunesMetadataArtist {
                                if let val = try? await item.load(.stringValue), !val.isEmpty {
                                    artist = val.trimmingCharacters(in: .whitespaces)
                                }
                            }
                        }
                        if album == nil {
                            if item.identifier == .id3MetadataAlbumTitle || item.identifier == .iTunesMetadataAlbum {
                                if let val = try? await item.load(.stringValue), !val.isEmpty {
                                    album = val.trimmingCharacters(in: .whitespaces)
                                }
                            }
                        }
                        if artworkData == nil {
                            if item.identifier == .id3MetadataAttachedPicture || item.identifier == .iTunesMetadataCoverArt {
                                artworkData = try? await item.load(.dataValue)
                            }
                        }
                        if lyricText == nil {
                            if item.identifier == .id3MetadataUnsynchronizedLyric || item.commonKey?.rawValue == "lyrics" {
                                lyricText = try? await item.load(.stringValue)
                            }
                        }
                    }
                }
            }
        }

        // 4. 优先检查同名同目录下的伴生 .lrc 歌词文件 (支持 UTF-8、Unicode 与 GB18030/GBK 编码)
        let lrcCandidates = [
            fileURL.deletingPathExtension().appendingPathExtension("lrc"),
            fileURL.deletingPathExtension().appendingPathExtension("LRC")
        ]
        for candidate in lrcCandidates {
            if FileManager.default.fileExists(atPath: candidate.path) {
                if let text = try? String(contentsOf: candidate, encoding: .utf8), !text.isEmpty {
                    lyricText = text
                    break
                } else if let text = try? String(contentsOf: candidate, encoding: .unicode), !text.isEmpty {
                    lyricText = text
                    break
                } else if let text = try? String(contentsOf: candidate, encoding: String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)))), !text.isEmpty {
                    lyricText = text
                    break
                }
            }
        }

        // 5. 兜底与智能文件名解析 (如 "周杰伦 - 晴天" 或 "晴天")
        var finalTitle = title ?? ""
        var finalArtist = artist ?? ""
        var finalAlbum = album ?? ""

        if finalTitle.isEmpty {
            if filename.contains(" - ") {
                let parts = filename.components(separatedBy: " - ")
                if parts.count >= 2 {
                    if finalArtist.isEmpty {
                        finalArtist = parts[0].trimmingCharacters(in: .whitespaces)
                    }
                    finalTitle = parts[1...].joined(separator: " - ").trimmingCharacters(in: .whitespaces)
                } else {
                    finalTitle = filename
                }
            } else {
                finalTitle = filename
            }
        }

        // 去除音轨序号前缀 (例如 "01. 晴天" 或 "01 - 晴天")
        if let match = try? /^\d{1,3}[\.\-\s]+(.+)/.wholeMatch(in: finalTitle) {
            finalTitle = String(match.1).trimmingCharacters(in: .whitespaces)
        }

        if finalArtist.isEmpty {
            finalArtist = "未知艺人"
        }
        if finalAlbum.isEmpty {
            finalAlbum = "本地音乐"
        }

        return LocalMetadata(
            title: finalTitle,
            artist: finalArtist,
            album: finalAlbum,
            durationMs: durationMs,
            artworkData: artworkData,
            lyricText: lyricText
        )
    }

    /// 生成确定性的稳定负数本地 ID
    private func generateLocalSongId(for filename: String) -> Int {
        var hasher: UInt64 = 5381
        for byte in filename.utf8 {
            hasher = ((hasher << 5) &+ hasher) &+ UInt64(byte)
        }
        let positive = Int(hasher & 0x7FFFFFFF)
        let safePositive = positive == 0 ? 1 : positive
        return -safePositive
    }

    // MARK: - Download Lifecycle Handlers (MainActor Isolated)

    private func handleDownloadFinished(songId: Int, stagedFile: URL, actualFileSize: Int64) {
        defer {
            try? FileManager.default.removeItem(at: stagedFile)
            finishActiveTask(for: songId)
        }

        guard let item = pendingItems.removeValue(forKey: songId) else {
            print("⚠️ 未找到 songId=\(songId) 的待保存下载信息")
            return
        }

        var song = item.song
        let destination = item.destination

        do {
            let targetDir = destination.deletingLastPathComponent()
            if !FileManager.default.fileExists(atPath: targetDir.path) {
                try FileManager.default.createDirectory(at: targetDir, withIntermediateDirectories: true, attributes: nil)
            }

            if FileManager.default.fileExists(atPath: destination.path) {
                try? FileManager.default.removeItem(at: destination)
            }

            do {
                try FileManager.default.moveItem(at: stagedFile, to: destination)
            } catch {
                try FileManager.default.copyItem(at: stagedFile, to: destination)
            }

            song.fileSize = actualFileSize

            downloadedSongs.removeAll(where: { $0.id == songId })
            downloadedSongs.insert(song, at: 0)
            saveMetadata()
            activeDownloads.removeValue(forKey: songId)
            downloadErrors.removeValue(forKey: songId)
            print("✅ 歌曲已成功下载至: \(destination.lastPathComponent) (\(song.fileSizeText))")
        } catch {
            print("❌ 移动已下载音频失败: \(error)")
            activeDownloads.removeValue(forKey: songId)
            downloadErrors[songId] = error.localizedDescription
        }
    }

    private func handleDownloadFailed(songId: Int, error: String) {
        activeDownloads.removeValue(forKey: songId)
        downloadErrors[songId] = error
        print("❌ 下载任务出错 [\(songId)]: \(error)")
        finishActiveTask(for: songId)
    }
}

// MARK: - URLSessionDownloadDelegate

extension DownloadManager: URLSessionDownloadDelegate {
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let idStr = downloadTask.taskDescription, let songId = Int(idStr) else { return }
        let progress: Double
        if totalBytesExpectedToWrite > 0 {
            progress = min(max(Double(totalBytesWritten) / Double(totalBytesExpectedToWrite), 0.05), 0.99)
        } else {
            progress = 0.5
        }

        Task { @MainActor [weak self] in
            guard let self = self, self.activeSongIds.contains(songId) else { return }
            self.activeDownloads[songId] = progress
        }
    }

    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let idStr = downloadTask.taskDescription, let songId = Int(idStr) else { return }

        // 1. 校验 HTTP 状态码
        if let httpResponse = downloadTask.response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
            let errorMsg = "下载服务器响应错误 (HTTP \(httpResponse.statusCode))"
            Task { @MainActor [weak self] in
                self?.handleDownloadFailed(songId: songId, error: errorMsg)
            }
            return
        }

        // 2. 校验文件实际大小（防止 HTML 403/404 伪装错误页或空文件）
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: location.path)[.size] as? Int64) ?? 0
        if fileSize < 1024 {
            let isHtml = (try? String(contentsOf: location, encoding: .utf8))?.contains("<html") ?? false
            let errorMsg = isHtml ? "下载音频防盗链拦截或链接失效" : "下载音频文件损坏或不完整"
            Task { @MainActor [weak self] in
                self?.handleDownloadFailed(songId: songId, error: errorMsg)
            }
            return
        }

        // 3. 在 delegate 返回前，立即将 location 移动到独立的暂存区，防止 URLSession 退出时自动删除临时文件
        let stagingURL = FileManager.default.temporaryDirectory.appendingPathComponent("dl_stage_\(songId)_\(UUID().uuidString)")
        do {
            try FileManager.default.moveItem(at: location, to: stagingURL)
        } catch {
            Task { @MainActor [weak self] in
                self?.handleDownloadFailed(songId: songId, error: error.localizedDescription)
            }
            return
        }

        // 4. 派发给主线程完成原子落盘与状态更新
        Task { @MainActor [weak self] in
            self?.handleDownloadFinished(songId: songId, stagedFile: stagingURL, actualFileSize: fileSize)
        }
    }

    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let idStr = task.taskDescription, let songId = Int(idStr) else { return }

        if let error = error {
            if (error as NSError).code != NSURLErrorCancelled {
                Task { @MainActor [weak self] in
                    self?.handleDownloadFailed(songId: songId, error: error.localizedDescription)
                }
            } else {
                Task { @MainActor [weak self] in
                    self?.finishActiveTask(for: songId)
                }
            }
        }
    }
}
