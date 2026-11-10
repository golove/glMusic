//
//  SongCoverThumbnailView.swift
//  glMusic
//
//  Created by go love on 11/10/26.
//

import SwiftUI
import AppKit
import ImageIO
import NeteaseCloudMusicAPI

/// 极速内存缩略图缓存 (O(1) 内存直读，避免重复网络加载与主线程图片解码)
final class SongThumbnailCache: @unchecked Sendable {
    static let shared = SongThumbnailCache()

    private let cache = NSCache<NSString, NSImage>()

    private init() {
        cache.countLimit = 1500
        cache.totalCostLimit = 64 * 1024 * 1024 // 64 MB
    }

    func image(forKey key: String) -> NSImage? {
        cache.object(forKey: key as NSString)
    }

    func setImage(_ image: NSImage, forKey key: String) {
        let cost = max(1, Int(image.size.width * image.size.height * 4))
        cache.setObject(image, forKey: key as NSString, cost: cost)
    }
}

/// 高性能歌曲封面缩略图组件 (零主线程磁盘 I/O，ImageIO 纯底层线程安全下采样，Retina 规格微缩解码)
struct SongCoverThumbnailView: View {
    let songId: Int
    let coverUrl: String?
    var size: CGFloat = 36

    init(songId: Int, coverUrl: String?, size: CGFloat = 36) {
        self.songId = songId
        self.coverUrl = coverUrl
        self.size = size
    }

    init(song: APISong, size: CGFloat = 36) {
        self.songId = song.id
        self.coverUrl = song.coverUrl
        self.size = size
    }

    @State private var thumbnailImage: NSImage?

    private var cacheKey: String {
        "song_\(songId)_\(Int(size))"
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
        .task(id: cacheKey) {
            await loadThumbnail()
        }
    }

    @MainActor
    private func loadThumbnail() async {
        // 1. 优先快查内存缓存 (零开销直读)
        if let cached = SongThumbnailCache.shared.image(forKey: cacheKey) {
            if thumbnailImage == nil {
                thumbnailImage = cached
            }
            return
        }

        // 2. 滚动流速节流门阀 (Fast-Scroll Throttle Guard):
        // 用户以毫秒级高速滑动掠过视口时，直接拦截取消，绝不滥发网络请求与消耗 CPU
        do {
            try await Task.sleep(nanoseconds: 120_000_000) // 120ms 视口驻留确认
        } catch {
            return // 滑动已掠过该行，直接放弃，0 网络，0 解码，0 CPU！
        }

        guard !Task.isCancelled else { return }

        // 3. 在主线程安全获取本地封面路径 (避免后台线程并发读取 DownloadManager 状态)
        let localCover = DownloadManager.shared.localCoverURL(for: songId)
        let remoteUrl = coverUrl
        let targetPixelSize = size * 2 // 2x Retina

        // 4. 后台使用纯 ImageIO 线程安全下采样 (结构化协作并发，随时响应 Task.isCancelled)
        let loaded = await Task(priority: .userInitiated) { () -> NSImage? in
            guard !Task.isCancelled else { return nil }

            // A. 本地文件下采样
            if let local = localCover,
               let cgThumb = downsample(url: local, maxPixelSize: targetPixelSize) {
                return NSImage(cgImage: cgThumb, size: CGSize(width: size, height: size))
            }

            // B. 远端图片下采样
            guard let urlStr = remoteUrl, !urlStr.isEmpty else { return nil }
            var fetchString = urlStr
            if fetchString.contains("music.126.net") && !fetchString.contains("?param=") {
                fetchString += "?param=\(Int(targetPixelSize))y\(Int(targetPixelSize))"
            }

            guard let url = URL(string: fetchString),
                  let (data, response) = try? await URLSession.shared.data(from: url),
                  (response as? HTTPURLResponse)?.statusCode == 200,
                  !Task.isCancelled,
                  let cgThumb = downsample(data: data, maxPixelSize: targetPixelSize) else {
                return nil
            }

            return NSImage(cgImage: cgThumb, size: CGSize(width: size, height: size))
        }.value

        guard !Task.isCancelled, let finalImage = loaded else { return }

        // 5. 写入内存高速缓存并更新视图
        SongThumbnailCache.shared.setImage(finalImage, forKey: cacheKey)
        self.thumbnailImage = finalImage
    }
}

/// 通用高性能缓存封面组件 (支持歌单大卡片、专辑封面、高频网格滚动优化)
struct CachedAsyncCoverView: View {
    let urlString: String?
    var placeholderIcon: String = "music.note.list"
    var targetSize: CGFloat = 200
    var cornerRadius: CGFloat = 10

    @State private var coverImage: NSImage?

    private var cacheKey: String {
        "cover_\(urlString ?? "")_\(Int(targetSize))"
    }

    var body: some View {
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
        .frame(
            minWidth: targetSize > 100 ? 140 : targetSize,
            maxWidth: targetSize > 100 ? .infinity : targetSize,
            minHeight: targetSize > 100 ? 140 : targetSize,
            maxHeight: targetSize > 100 ? .infinity : targetSize
        )
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .task(id: cacheKey) {
            await loadCover()
        }
    }

    @MainActor
    private func loadCover() async {
        guard let urlStr = urlString, !urlStr.isEmpty else { return }

        // 1. 优先内存查找
        if let cached = SongThumbnailCache.shared.image(forKey: cacheKey) {
            if coverImage == nil {
                coverImage = cached
            }
            return
        }

        // 2. 滚动流速节流门阀：高速掠过视口不足 120ms 的卡片，直接取消，绝不滥发请求与消耗 CPU
        do {
            try await Task.sleep(nanoseconds: 120_000_000)
        } catch {
            return
        }

        guard !Task.isCancelled else { return }

        let pixelDim = targetSize * 2 // 2x Retina
        let displaySize = targetSize

        // 3. 后台纯底层 ImageIO 协作任务
        let loaded = await Task(priority: .userInitiated) { () -> NSImage? in
            guard !Task.isCancelled else { return nil }

            var fetchUrl = urlStr
            if fetchUrl.contains("music.126.net") && !fetchUrl.contains("?param=") {
                fetchUrl += "?param=\(Int(pixelDim))y\(Int(pixelDim))"
            }

            guard let url = URL(string: fetchUrl),
                  let (data, response) = try? await URLSession.shared.data(from: url),
                  (response as? HTTPURLResponse)?.statusCode == 200,
                  !Task.isCancelled,
                  let cgThumb = downsample(data: data, maxPixelSize: pixelDim) else {
                return nil
            }

            return NSImage(cgImage: cgThumb, size: CGSize(width: displaySize, height: displaySize))
        }.value

        guard !Task.isCancelled, let finalImage = loaded else { return }

        SongThumbnailCache.shared.setImage(finalImage, forKey: cacheKey)
        self.coverImage = finalImage
    }
}

// MARK: - ImageIO 纯底层高质量硬解与下采样引擎 (Apple 官方推荐零内存暴涨方案)

private func downsample(data: Data, maxPixelSize: CGFloat) -> CGImage? {
    let options: [CFString: Any] = [
        kCGImageSourceShouldCache: false,
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceCreateThumbnailWithTransform: true,
        kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
    ]
    guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary) else {
        return nil
    }
    return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
}

private func downsample(url: URL, maxPixelSize: CGFloat) -> CGImage? {
    let options: [CFString: Any] = [
        kCGImageSourceShouldCache: false,
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceCreateThumbnailWithTransform: true,
        kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
    ]
    guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary) else {
        return nil
    }
    return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
}
