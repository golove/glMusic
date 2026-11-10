//
//  StreamingCacheManager.swift
//  glMusic
//
//  Created by go love on 11/9/26.
//

import Foundation

/// 局域在线音频 LRU 磁盘缓存管理器（边播边存，二次收听 0 缓冲、0 流量、秒起播）
actor StreamingCacheManager {
    static let shared = StreamingCacheManager()

    private struct CacheRecord: Codable {
        let songId: Int
        let fileName: String
        let fileSize: Int64
        var lastAccessedAt: Date
    }

    private let cacheDirectory: URL
    private let indexFileURL: URL
    private let maxCacheSizeBytes: Int64 = 1500 * 1024 * 1024 // 默认配额 1.5 GB
    private var records: [Int: CacheRecord] = [:]
    private var activeCachingTaskIds: Set<Int> = []

    private init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let dir = caches.appendingPathComponent("StreamingAudio", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        self.cacheDirectory = dir
        self.indexFileURL = dir.appendingPathComponent("streaming_cache_index.json")

        loadIndex()
    }

    /// 查询本地是否已缓存该在线音频并已校验存在
    func cachedAudioURL(for songId: Int) -> URL? {
        guard let record = records[songId] else { return nil }
        let fileURL = cacheDirectory.appendingPathComponent(record.fileName)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            records[songId]?.lastAccessedAt = Date()
            saveIndex()
            return fileURL
        } else {
            records.removeValue(forKey: songId)
            saveIndex()
            return nil
        }
    }

    /// 触发后台异步缓存任务
    func cacheSongIfNeeded(songId: Int, remoteURL: URL) {
        guard songId > 0 else { return }
        if records[songId] != nil || activeCachingTaskIds.contains(songId) { return }

        activeCachingTaskIds.insert(songId)

        Task.detached(priority: .utility) { [weak self] in
            guard let self = self else { return }
            await self.downloadAndStore(songId: songId, remoteURL: remoteURL)
        }
    }

    private func downloadAndStore(songId: Int, remoteURL: URL) async {
        defer {
            activeCachingTaskIds.remove(songId)
        }

        do {
            let (tempURL, response) = try await URLSession.shared.download(from: remoteURL)
            guard let httpResp = response as? HTTPURLResponse, (200...299).contains(httpResp.statusCode) else {
                return
            }

            let ext = remoteURL.pathExtension.isEmpty ? "mp3" : remoteURL.pathExtension
            let fileName = "cache_\(songId).\(ext)"
            let destinationURL = cacheDirectory.appendingPathComponent(fileName)

            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try? FileManager.default.removeItem(at: destinationURL)
            }

            try FileManager.default.moveItem(at: tempURL, to: destinationURL)

            let attrs = try? FileManager.default.attributesOfItem(atPath: destinationURL.path)
            let fileSize = (attrs?[.size] as? Int64) ?? 0

            records[songId] = CacheRecord(
                songId: songId,
                fileName: fileName,
                fileSize: fileSize,
                lastAccessedAt: Date()
            )

            #if DEBUG
            print("💾 [glMusic] 在线音频流已自动完成本地磁盘缓存 (ID: \(songId), 大小: \(ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)))")
            #endif

            pruneIfNeeded()
            saveIndex()
        } catch {
            #if DEBUG
            print("⚠️ [glMusic] 在线音频后台缓存失败: \(error)")
            #endif
        }
    }

    /// LRU 自动清理淘汰超限旧数据
    private func pruneIfNeeded() {
        var totalSize = records.values.reduce(Int64(0)) { $0 + $1.fileSize }
        guard totalSize > maxCacheSizeBytes else { return }

        // 按最近访问时间升序排序（最旧的排在前面）
        let sorted = records.values.sorted { $0.lastAccessedAt < $1.lastAccessedAt }
        for record in sorted {
            let fileURL = cacheDirectory.appendingPathComponent(record.fileName)
            try? FileManager.default.removeItem(at: fileURL)
            records.removeValue(forKey: record.songId)
            totalSize -= record.fileSize

            if totalSize <= Int64(Double(maxCacheSizeBytes) * 0.8) { // 清理至 80%
                break
            }
        }
    }

    /// 获取当前磁盘缓存占用
    func currentCacheSizeFormatted() -> String {
        let total = records.values.reduce(Int64(0)) { $0 + $1.fileSize }
        return ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
    }

    /// 清空所有流媒体缓存
    func clearAll() {
        for record in records.values {
            let fileURL = cacheDirectory.appendingPathComponent(record.fileName)
            try? FileManager.default.removeItem(at: fileURL)
        }
        records.removeAll()
        saveIndex()
    }

    private func loadIndex() {
        guard FileManager.default.fileExists(atPath: indexFileURL.path),
              let data = try? Data(contentsOf: indexFileURL),
              let list = try? JSONDecoder().decode([CacheRecord].self, from: data) else {
            return
        }
        for item in list {
            records[item.songId] = item
        }
    }

    private func saveIndex() {
        let list = Array(records.values)
        if let data = try? JSONEncoder().encode(list) {
            try? data.write(to: indexFileURL, options: .atomic)
        }
    }
}
