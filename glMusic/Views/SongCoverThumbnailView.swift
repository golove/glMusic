//
//  SongCoverThumbnailView.swift
//  glMusic
//
//  Created by go love on 11/10/26.
//

import SwiftUI
import AppKit
import ImageIO
import CryptoKit
import NeteaseCloudMusicAPI

// MARK: - CDN 端云协同参数处理 (网易云音乐 CDN 原生动态缩略图注入)

nonisolated func appendingCDNThumbnailParam(to urlStr: String, pixelSize: Int) -> String {
    guard urlStr.contains("music.126.net") || urlStr.contains("126.net") else {
        return urlStr
    }
    // 已包含尺寸参数则无需重复拼接
    if urlStr.contains("param=") {
        return urlStr
    }
    let param = "param=\(pixelSize)y\(pixelSize)"
    if urlStr.contains("?") {
        return "\(urlStr)&\(param)"
    } else {
        return "\(urlStr)?\(param)"
    }
}

// MARK: - 磁盘二级轻量缓存 (仅存储 Downsample 后的微缩图数据，秒开且极省磁盘)

final class ThumbnailDiskCache: @unchecked Sendable {
    nonisolated static let shared = ThumbnailDiskCache()
    private let diskURL: URL
    private let fileManager = FileManager.default
    private let ioQueue = DispatchQueue(label: "com.glmusic.thumbnaildiskcache", qos: .utility)

    private init() {
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        self.diskURL = caches.appendingPathComponent("glmusic_thumbnails", isDirectory: true)
        try? fileManager.createDirectory(at: diskURL, withIntermediateDirectories: true)
    }

    private func filePath(for key: String) -> URL {
        let hash = SHA256.hash(data: Data(key.utf8)).compactMap { String(format: "%02x", $0) }.joined()
        return diskURL.appendingPathComponent(hash)
    }

    nonisolated func data(forKey key: String) -> Data? {
        let file = filePath(for: key)
        guard fileManager.fileExists(atPath: file.path) else { return nil }
        return try? Data(contentsOf: file)
    }

    nonisolated func setData(_ data: Data, forKey key: String) {
        let file = filePath(for: key)
        ioQueue.async { [weak self] in
            guard self != nil else { return }
            try? data.write(to: file, options: .atomic)
        }
    }

    nonisolated func removeAll() {
        ioQueue.async { [weak self] in
            guard let self = self else { return }
            try? self.fileManager.removeItem(at: self.diskURL)
            try? self.fileManager.createDirectory(at: self.diskURL, withIntermediateDirectories: true)
        }
    }
}

// MARK: - 极速内存图片缓存 (O(1) 内存直读，避免重复网络加载与主线程图片解码)

final class SongThumbnailCache: @unchecked Sendable {
    nonisolated static let shared = SongThumbnailCache()

    private let cache = NSCache<NSString, NSImage>()
    private let lock = NSLock()

    private init() {
        cache.countLimit = 1200
        cache.totalCostLimit = 96 * 1024 * 1024 // 96 MB 内存预算 (针对下采样后的微缩位图)

        // 监听系统进入后台或内存告警，适时清理非热点缓存
        NotificationCenter.default.addObserver(
            forName: NSApplication.willResignActiveNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            guard let self = self else { return }
            self.lock.withLock {
                self.cache.totalCostLimit = 48 * 1024 * 1024
                self.cache.totalCostLimit = 96 * 1024 * 1024
            }
        }
    }

    nonisolated func image(forKey key: String) -> NSImage? {
        lock.withLock {
            cache.object(forKey: key as NSString)
        }
    }

    nonisolated func setImage(_ image: NSImage, forKey key: String) {
        // 存储的是经过 Downsample 的 NSImage，cost 精准计算其实际位图内存大小
        let cost = max(1, Int(image.size.width * image.size.height * 4))
        lock.withLock {
            cache.setObject(image, forKey: key as NSString, cost: cost)
        }
    }

    nonisolated func removeImage(forKey key: String) {
        lock.withLock {
            cache.removeObject(forKey: key as NSString)
        }
    }

    nonisolated func removeAll() {
        lock.withLock {
            cache.removeAllObjects()
        }
    }
}

// MARK: - ImagePipelineManager (Actor 任务去重、并发限流、后台硬解与级联取消)

actor ImagePipelineManager {
    static let shared = ImagePipelineManager()

    /// 正在进行的下载与解码任务表 (Request Coalescing: 相同 URL 与规格的请求复用同一 Task)
    private var inFlightTasks: [String: Task<NSImage?, Never>] = [:]
    /// 每个请求的活跃订阅者数量
    private var taskSubscribers: [String: Int] = [:]

    /// 并发限流槽位控制 (最大 6 个并发下载/硬解任务，防止滚动瞬发数十个 Task 导致 CPU 满载)
    private let maxConcurrent: Int = 6
    private var runningCount: Int = 0
    private var waiters: [CheckedContinuation<Void, Never>] = []

    private func acquireSlot() async {
        if runningCount < maxConcurrent {
            runningCount += 1
            return
        }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    private func releaseSlot() {
        if !waiters.isEmpty {
            let next = waiters.removeFirst()
            next.resume()
        } else {
            runningCount = max(0, runningCount - 1)
        }
    }

    /// 取消某个订阅者的关注，当没有关注者时，取消底层任务并清理
    func cancelSubscriber(forKey cacheKey: String) {
        guard let count = taskSubscribers[cacheKey] else { return }
        if count <= 1 {
            taskSubscribers.removeValue(forKey: cacheKey)
            if let task = inFlightTasks.removeValue(forKey: cacheKey) {
                task.cancel()
            }
        } else {
            taskSubscribers[cacheKey] = count - 1
        }
    }

    /// 加载并进行端云协同下采样 + 后台 ImageIO 硬解 + 二级缓存联动
    /// - Parameters:
    ///   - urlString: 远程或本地图片 URL 字符串
    ///   - targetSize: 显示逻辑点尺寸 (pt)
    ///   - scale: 屏幕像素倍率 (Retina 默认 2.0)
    /// - Returns: 解码好的下采样 NSImage (主线程可 0ms 直接渲染)
    func loadImage(for urlString: String?, targetSize: CGFloat, scale: CGFloat = 2.0) async -> NSImage? {
        guard let urlStr = urlString, !urlStr.isEmpty else { return nil }

        let targetPixelSize = max(32, targetSize * scale)
        let cacheKey = "cover_\(urlStr)_\(Int(targetPixelSize))"

        // 1. 检查内存缓存 (已是下采样后的就绪位图)
        if let cached = SongThumbnailCache.shared.image(forKey: cacheKey) {
            return cached
        }

        // 2. 检查本地磁盘二级缓存 (冷启动与内存释放后极速恢复)
        if let diskData = ThumbnailDiskCache.shared.data(forKey: cacheKey) {
            if let cgThumb = downsample(data: diskData, maxPixelSize: targetPixelSize) {
                let diskImage = NSImage(cgImage: cgThumb, size: CGSize(width: targetSize, height: targetSize))
                SongThumbnailCache.shared.setImage(diskImage, forKey: cacheKey)
                return diskImage
            }
        }

        // 3. 检查是否有相同的任务正在进行中 (请求去重与级联取消)
        if let existingTask = inFlightTasks[cacheKey] {
            taskSubscribers[cacheKey, default: 1] += 1
            return await withTaskCancellationHandler {
                await existingTask.value
            } onCancel: {
                Task { [cacheKey] in
                    await ImagePipelineManager.shared.cancelSubscriber(forKey: cacheKey)
                }
            }
        }

        // 4. 开启后台结构化任务
        let task = Task<NSImage?, Never>(priority: .userInitiated) { () -> NSImage? in
            await self.acquireSlot()
            defer {
                Task {
                    await self.releaseSlot()
                }
            }

            guard !Task.isCancelled else { return nil }

            // 端云协同：网易云 CDN 自动拼接缩略图尺寸参数，减少 90% 网络传输带宽
            let fetchUrlStr = appendingCDNThumbnailParam(to: urlStr, pixelSize: Int(targetPixelSize))
            guard let url = URL(string: fetchUrlStr) else { return nil }

            // 处理本地文件与网络文件
            if url.isFileURL {
                guard let cgThumb = downsample(url: url, maxPixelSize: targetPixelSize) else {
                    return nil
                }
                return NSImage(cgImage: cgThumb, size: CGSize(width: targetSize, height: targetSize))
            }

            guard let (data, response) = try? await URLSession.shared.data(from: url),
                  (response as? HTTPURLResponse)?.statusCode == 200,
                  !Task.isCancelled else {
                return nil
            }

            // ImageIO 后台强制立即解码位图 (kCGImageSourceShouldCacheImmediately: true)
            guard let cgThumb = downsample(data: data, maxPixelSize: targetPixelSize) else {
                return nil
            }

            // 将下采样后的微缩位图异步写入磁盘缓存，避免保存数兆原图
            if let jpegData = encodeCGImageToJPEG(image: cgThumb) {
                ThumbnailDiskCache.shared.setData(jpegData, forKey: cacheKey)
            }

            let decodedImage = NSImage(cgImage: cgThumb, size: CGSize(width: targetSize, height: targetSize))
            return decodedImage
        }

        inFlightTasks[cacheKey] = task
        taskSubscribers[cacheKey] = 1

        let finalImage = await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            Task { [cacheKey] in
                await ImagePipelineManager.shared.cancelSubscriber(forKey: cacheKey)
            }
        }

        inFlightTasks.removeValue(forKey: cacheKey)
        taskSubscribers.removeValue(forKey: cacheKey)

        if let finalImage = finalImage {
            // 直接缓存下采样后的图片，下次读取零缩放开销
            SongThumbnailCache.shared.setImage(finalImage, forKey: cacheKey)
        }

        return finalImage
    }
}

// MARK: - 高性能歌曲封面缩略图组件 (专为播放列表、歌曲行设计)

struct SongCoverThumbnailView: View {
    let songId: Int
    let coverUrl: String?
    var size: CGFloat = 36
    var cancelOnDisappear: Bool = true

    init(songId: Int, coverUrl: String?, size: CGFloat = 36, cancelOnDisappear: Bool = true) {
        self.songId = songId
        self.coverUrl = coverUrl
        self.size = size
        self.cancelOnDisappear = cancelOnDisappear
    }

    init(song: APISong, size: CGFloat = 36, cancelOnDisappear: Bool = true) {
        self.songId = song.id
        self.coverUrl = song.coverUrl
        self.size = size
        self.cancelOnDisappear = cancelOnDisappear
    }

    @State private var thumbnailImage: NSImage?
    @State private var currentTask: Task<Void, Never>?

    private var cacheKey: String {
        "song_\(songId)_\(Int(size * 2))"
    }

    var body: some View {
        Group {
            if let img = thumbnailImage ?? SongThumbnailCache.shared.image(forKey: cacheKey) {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Rectangle()
                    .fill(.quaternary)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: size * 0.35))
                            .foregroundStyle(.tertiary)
                    )
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .onAppear {
            startLoading()
        }
        .onDisappear {
            if cancelOnDisappear {
                currentTask?.cancel()
                currentTask = nil
            }
        }
        .onChange(of: songId) { _, _ in
            thumbnailImage = nil
            startLoading()
        }
    }

    private func startLoading() {
        // 1. 优先内存快查 (0ms 瞬时渲染)
        if let cached = SongThumbnailCache.shared.image(forKey: cacheKey) {
            thumbnailImage = cached
            return
        }

        currentTask?.cancel()
        currentTask = Task { @MainActor in
            // 2. 快速滑动节流门阀 (80ms 视口停留确认)
            do {
                try await Task.sleep(nanoseconds: 80_000_000)
            } catch {
                return // 滑动掠过，直接放弃，0 网络，0 解码，0 CPU
            }

            guard !Task.isCancelled else { return }

            // 3. 检查本地封面
            let localCover = DownloadManager.shared.localCoverURL(for: songId)
            let targetPixelSize = size * 2

            if let local = localCover {
                let img = await Task.detached(priority: .userInitiated) { () -> NSImage? in
                    guard let cgThumb = downsample(url: local, maxPixelSize: targetPixelSize) else { return nil }
                    return NSImage(cgImage: cgThumb, size: CGSize(width: size, height: size))
                }.value

                guard !Task.isCancelled, let finalImage = img else { return }
                SongThumbnailCache.shared.setImage(finalImage, forKey: cacheKey)
                self.thumbnailImage = finalImage
                return
            }

            // 4. 通过管道加载网络图片 (后台硬解 + 去重 + 限流 + 取消联动)
            if let remote = coverUrl, !remote.isEmpty {
                let img = await ImagePipelineManager.shared.loadImage(
                    for: remote,
                    targetSize: size,
                    scale: 2.0
                )
                guard !Task.isCancelled, let finalImage = img else { return }
                SongThumbnailCache.shared.setImage(finalImage, forKey: cacheKey)
                self.thumbnailImage = finalImage
            }
        }
    }
}

// MARK: - 通用高性能缓存封面组件 (支持歌单大卡片、专辑封面、高频网格滚动优化)

struct CachedAsyncCoverView: View {
    let urlString: String?
    var placeholderIcon: String = "music.note.list"
    var targetSize: CGFloat = 200
    var cornerRadius: CGFloat = 10
    var cancelOnDisappear: Bool = true
    var fixedSize: Bool = false
    var customHeight: CGFloat? = nil
    var keepAspectRatio: Bool = true

    @State private var coverImage: NSImage?
    @State private var loadTask: Task<Void, Never>?

    private var cacheKey: String {
        let pixelSize = max(targetSize, customHeight ?? targetSize) * 2
        return "cover_\(urlString ?? "")_\(Int(pixelSize))"
    }

    private var baseContent: some View {
        Group {
            if let img = coverImage ?? SongThumbnailCache.shared.image(forKey: cacheKey) {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Rectangle()
                    .fill(.quaternary)
                    .overlay(
                        Image(systemName: placeholderIcon)
                            .font(.system(size: targetSize > 100 ? 22 : max(9, targetSize * 0.5)))
                            .foregroundStyle(.tertiary)
                    )
            }
        }
    }

    var body: some View {
        Group {
            if let h = customHeight {
                baseContent
                    .frame(width: targetSize, height: h)
            } else if fixedSize {
                baseContent
                    .frame(width: targetSize, height: targetSize)
            } else {
                baseContent
                    .frame(
                        minWidth: targetSize > 100 ? 140 : targetSize,
                        maxWidth: targetSize > 100 ? .infinity : targetSize,
                        minHeight: targetSize > 100 ? 140 : targetSize,
                        maxHeight: targetSize > 100 ? .infinity : targetSize
                    )
                    .aspectRatio(keepAspectRatio ? 1 : nil, contentMode: .fit)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .onAppear {
            startLoading()
        }
        .onDisappear {
            if cancelOnDisappear {
                loadTask?.cancel()
                loadTask = nil
            }
        }
        .onChange(of: urlString) { _, _ in
            coverImage = nil
            startLoading()
        }
    }

    private func startLoading() {
        // 1. 优先内存快查 (0ms 瞬时命中)
        if let cached = SongThumbnailCache.shared.image(forKey: cacheKey) {
            coverImage = cached
            return
        }

        loadTask?.cancel()
        loadTask = Task { @MainActor in
            // 2. 快速滑动节流门阀 (80ms 视口停留确认，防止飞速滑动时产生并发排队)
            do {
                try await Task.sleep(nanoseconds: 80_000_000)
            } catch {
                return
            }

            guard !Task.isCancelled else { return }

            // 3. 通过后台 ImagePipelineManager 统一加载、下采样与后台解码
            let img = await ImagePipelineManager.shared.loadImage(
                for: urlString,
                targetSize: targetSize,
                scale: 2.0
            )

            guard !Task.isCancelled, let finalImage = img else { return }
            self.coverImage = finalImage
        }
    }
}

// MARK: - ImageIO 纯底层高质量硬解与下采样引擎 (Apple 官方推荐零内存暴涨方案)

/// 纯后台 ImageIO 线程安全下采样引擎 (从内存 Data 解码)
/// 强制开启 kCGImageSourceShouldCacheImmediately: true，确保 100% 后台解压位图，禁止主线程解码
nonisolated func downsample(data: Data, maxPixelSize: CGFloat) -> CGImage? {
    let sourceOptions: [CFString: Any] = [
        kCGImageSourceShouldCache: false
    ]
    guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions as CFDictionary) else {
        return nil
    }

    let thumbnailOptions: [CFString: Any] = [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceShouldCacheImmediately: true, // 核心！强制在后台线程执行解压与解码
        kCGImageSourceCreateThumbnailWithTransform: true,
        kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
    ]
    return CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions as CFDictionary)
}

/// 纯后台 ImageIO 线程安全下采样引擎 (从本地文件 URL 解码)
/// 强制开启 kCGImageSourceShouldCacheImmediately: true，确保 100% 后台解压位图，禁止主线程解码
nonisolated func downsample(url: URL, maxPixelSize: CGFloat) -> CGImage? {
    let sourceOptions: [CFString: Any] = [
        kCGImageSourceShouldCache: false
    ]
    guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions as CFDictionary) else {
        return nil
    }

    let thumbnailOptions: [CFString: Any] = [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceShouldCacheImmediately: true, // 核心！强制在后台线程执行解压与解码
        kCGImageSourceCreateThumbnailWithTransform: true,
        kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
    ]
    return CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions as CFDictionary)
}

/// 将 CGImage 编码为轻量 JPEG 数据，用于写入微缩图磁盘缓存 (后台执行，极低 IO 消耗)
nonisolated func encodeCGImageToJPEG(image: CGImage, quality: CGFloat = 0.82) -> Data? {
    let data = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(data as CFMutableData, "public.jpeg" as CFString, 1, nil) else {
        return nil
    }
    let options: [CFString: Any] = [
        kCGImageDestinationLossyCompressionQuality: quality
    ]
    CGImageDestinationAddImage(destination, image, options as CFDictionary)
    guard CGImageDestinationFinalize(destination) else { return nil }
    return data as Data
}
