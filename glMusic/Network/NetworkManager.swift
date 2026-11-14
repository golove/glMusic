//
//  NetworkManager.swift
//  glMusic
//
//  Created by go love on 10/23/26.
//  Updated to Native Swift SDK direct connection + VIP Smart Unblock.
//

import Foundation
import AppKit
import CoreImage
import CryptoKit
import NeteaseCloudMusicAPI

// MARK: - API Cache Layer (L1 内存 + L2 磁盘二级缓存体系，支持 SHA-256 防冲突与容量限制)

actor APICache {
    static let shared = APICache()

    private final class CacheEntryBox {
        let data: Any
        let expiration: Date
        init(data: Any, expiration: Date) {
            self.data = data
            self.expiration = expiration
        }
    }

    private struct DiskEntry: Codable {
        let rawData: Data
        let expiration: Date
    }

    /// L1 内存缓存：使用带容量限制与系统内存压力自动释放机制的 NSCache
    private let memoryCache: NSCache<NSString, CacheEntryBox> = {
        let cache = NSCache<NSString, CacheEntryBox>()
        cache.countLimit = 500 // 限制最大缓存条目数，防止无上限膨胀
        return cache
    }()

    private let diskCacheDirectory: URL
    private let maxDiskBytes: Int64 = 150 * 1024 * 1024 // 150 MB 磁盘配额
    private var lastTrimTime: Date = .distantPast

    private init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let dir = caches.appendingPathComponent("APICache", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        self.diskCacheDirectory = dir
    }

    /// 使用 SHA-256 哈希作为文件名，彻底杜绝特殊字符替换造成的缓存键碰撞冲突
    private func fileURL(for key: String) -> URL {
        let hash = SHA256.hash(data: Data(key.utf8))
        let hex = hash.map { String(format: "%02x", $0) }.joined()
        return diskCacheDirectory.appendingPathComponent("\(hex).cache")
    }

    func get<T>(_ key: String) -> T? {
        let nsKey = key as NSString

        // 1. 优先从 L1 内存缓存命中
        if let entry = memoryCache.object(forKey: nsKey) {
            if Date() < entry.expiration {
                return entry.data as? T
            } else {
                memoryCache.removeObject(forKey: nsKey)
                removeDiskCache(for: key)
                return nil
            }
        }

        // 2. 从 L2 磁盘缓存查询并回填
        if let decodableType = T.self as? any Decodable.Type {
            let targetURL = fileURL(for: key)
            if FileManager.default.fileExists(atPath: targetURL.path),
               let fileData = try? Data(contentsOf: targetURL),
               let diskEntry = try? JSONDecoder().decode(DiskEntry.self, from: fileData) {
                if Date() < diskEntry.expiration {
                    if let decoded = try? JSONDecoder().decode(decodableType, from: diskEntry.rawData) as? T {
                        memoryCache.setObject(CacheEntryBox(data: decoded, expiration: diskEntry.expiration), forKey: nsKey)
                        // 3. 命中读取时刷新文件修改时间，实现真正按访问时间排序的 LRU
                        try? FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: targetURL.path)
                        return decoded
                    }
                } else {
                    try? FileManager.default.removeItem(at: targetURL)
                }
            }
        }

        return nil
    }

    func set<T>(_ key: String, value: T, ttl: TimeInterval) {
        let expiration = Date().addingTimeInterval(ttl)
        let nsKey = key as NSString

        // 1. 写入 L1 内存
        memoryCache.setObject(CacheEntryBox(data: value, expiration: expiration), forKey: nsKey)

        // 2. 异步序列化写入 L2 磁盘缓存
        if let encodableVal = value as? any Encodable {
            let targetURL = fileURL(for: key)
            Task.detached(priority: .background) {
                if let rawData = try? JSONEncoder().encode(encodableVal) {
                    let diskEntry = DiskEntry(rawData: rawData, expiration: expiration)
                    if let entryData = try? JSONEncoder().encode(diskEntry) {
                        try? entryData.write(to: targetURL, options: .atomic)
                    }
                }
            }
        }

        trimDiskCacheIfNeeded()
    }

    func remove(_ key: String) {
        memoryCache.removeObject(forKey: key as NSString)
        removeDiskCache(for: key)
    }

    private func removeDiskCache(for key: String) {
        let targetURL = fileURL(for: key)
        try? FileManager.default.removeItem(at: targetURL)
    }

    func clearAll() {
        memoryCache.removeAllObjects()
        if let files = try? FileManager.default.contentsOfDirectory(at: diskCacheDirectory, includingPropertiesForKeys: nil) {
            for f in files {
                try? FileManager.default.removeItem(at: f)
            }
        }
    }

    /// 定期 LRU 淘汰：超过 150MB 配额时，自动清理最早修改的缓存文件至安全水位
    private func trimDiskCacheIfNeeded() {
        let now = Date()
        guard now.timeIntervalSince(lastTrimTime) > 300 else { return } // 最多每 5 分钟触发一次
        lastTrimTime = now

        let dir = diskCacheDirectory
        let maxBytes = maxDiskBytes

        Task.detached(priority: .utility) {
            guard let files = try? FileManager.default.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey]
            ) else { return }

            var totalSize: Int64 = 0
            var fileItems: [(url: URL, size: Int64, date: Date)] = []

            for file in files {
                guard file.pathExtension == "cache",
                      let values = try? file.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey]) else {
                    continue
                }
                let size = Int64(values.fileSize ?? 0)
                let date = values.contentModificationDate ?? Date.distantPast
                totalSize += size
                fileItems.append((file, size, date))
            }

            if totalSize > maxBytes {
                let sorted = fileItems.sorted(by: { $0.date < $1.date })
                var currentSize = totalSize
                let targetSize = Int64(Double(maxBytes) * 0.75)

                for item in sorted {
                    if currentSize <= targetSize { break }
                    try? FileManager.default.removeItem(at: item.url)
                    currentSize -= item.size
                }
            }
        }
    }
}

// MARK: - Network Manager (原生直连 + 智能解灰)

final class NetworkManager: @unchecked Sendable {
    static let shared = NetworkManager()

    /// 官方原生 EAPI / WeAPI 直连客户端（无需本地 Node.js 3000 服务）
    public let client: NCMClient

    /// 第三方智能换源解灰管理器（解决 VIP 试听 30s/45s 限制及无版权灰色歌曲）
    public let unblockManager: UnblockManager

    /// 智能解灰总开关
    public var autoUnblockEnabled: Bool = true

    private init() {
        self.client = NCMClient()
        self.unblockManager = UnblockManager()

        // 注册优质解灰音源（GD音乐台，支持全曲 320k 匹配）
        self.unblockManager.register(ServerUnblockSource.gd(name: "GD音乐台"))

        // 关闭 SDK 内部 autoUnblock，统一由 NetworkManager / PlayerManager 安全接管，避免 Cocoa 字典修改崩溃
        self.client.autoUnblock = false

        // 恢复保存的网易云 Cookie (从 Keychain 读取，支持从旧版 UserDefaults 自动平滑迁移)
        if let savedCookie = KeychainHelper.loadCookie(), !savedCookie.isEmpty {
            self.client.setCookie(savedCookie)
        } else if let legacyCookie = UserDefaults.standard.string(forKey: "netease_cookie"), !legacyCookie.isEmpty {
            KeychainHelper.saveCookie(legacyCookie)
            UserDefaults.standard.removeObject(forKey: "netease_cookie")
            self.client.setCookie(legacyCookie)
        }
    }

    // MARK: - Cache Invalidation

    func clearCache() async {
        await APICache.shared.clearAll()
    }

    // MARK: - Cookie 管理 (钥匙串加密安全隔离)

    var cookie: String? {
        get {
            KeychainHelper.loadCookie() ?? UserDefaults.standard.string(forKey: "netease_cookie")
        }
        set {
            if let val = newValue, !val.isEmpty {
                KeychainHelper.saveCookie(val)
                UserDefaults.standard.removeObject(forKey: "netease_cookie")
                client.setCookie(val)
            } else {
                KeychainHelper.deleteCookie()
                UserDefaults.standard.removeObject(forKey: "netease_cookie")
                client.setCookie("")
            }
        }
    }

    var isLoggedIn: Bool {
        guard let c = cookie else { return false }
        return !c.isEmpty
    }

    func logout() {
        cookie = nil
        client.setCookie("")
        Task { await clearCache() }
    }

    // MARK: - 内部解码工具

    private func decodeResponse<T: Codable>(_ response: APIResponse) throws -> T {
        let data = try JSONSerialization.data(withJSONObject: response.body)
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError.decodingFailed(underlying: error)
        }
    }

    // MARK: - 游客登录（获取基础 Cookie）

    func registerAnonymous() async throws {
        let resp = try await client.registerAnonimous()
        if let c = resp.body["cookie"] as? String {
            self.cookie = c
        }
    }

    // MARK: - 二维码登录

    func getQRKey() async throws -> String {
        let resp = try await client.loginQrKey()
        guard let key = (resp.body["data"] as? [String: Any])?["unikey"] as? String
                ?? resp.body["unikey"] as? String else {
            throw APIError.noData
        }
        return key
    }

    func createQR(key: String) async throws -> String {
        let resp = try await client.loginQrCreate(key: key, qrimg: true)
        let dataDict = resp.body["data"] as? [String: Any] ?? resp.body

        // 优先使用服务端返回的 base64 图片
        if let qrimg = dataDict["qrimg"] as? String, !qrimg.isEmpty {
            return qrimg
        }

        // 若仅返回 qrurl，本地通过 CoreImage 生成二维码 Base64
        if let qrurl = dataDict["qrurl"] as? String,
           let qrData = qrurl.data(using: .utf8),
           let filter = CIFilter(name: "CIQRCodeGenerator") {
            filter.setValue(qrData, forKey: "inputMessage")
            filter.setValue("M", forKey: "inputCorrectionLevel")
            if let ciImage = filter.outputImage {
                let rep = NSCIImageRep(ciImage: ciImage.transformed(by: CGAffineTransform(scaleX: 8, y: 8)))
                let nsImage = NSImage(size: rep.size)
                nsImage.addRepresentation(rep)
                if let tiff = nsImage.tiffRepresentation,
                   let bitmap = NSBitmapImageRep(data: tiff),
                   let png = bitmap.representation(using: .png, properties: [:]) {
                    return "data:image/png;base64," + png.base64EncodedString()
                }
            }
        }

        throw APIError.noData
    }

    func checkQR(key: String) async throws -> QRCheckResponse {
        let resp = try await client.loginQrCheck(key: key)
        let r: QRCheckResponse = try decodeResponse(resp)
        if let c = r.cookie, !c.isEmpty {
            self.cookie = c
        }
        return r
    }

    // MARK: - 短信验证码登录

    func sendCaptcha(phone: String) async throws {
        _ = try await client.captchaSent(phone: phone)
    }

    func loginWithCaptcha(phone: String, captcha: String) async throws -> String? {
        let resp = try await client.loginCellphone(phone: phone, captcha: captcha)
        if let c = resp.body["cookie"] as? String {
            self.cookie = c
            return c
        }
        return nil
    }

    // MARK: - 登录状态

    func loginStatus() async throws -> UserProfile? {
        let resp = try await client.loginStatus()
        if let profileDict = resp.body["profile"] as? [String: Any]
            ?? (resp.body["data"] as? [String: Any])?["profile"] as? [String: Any] {
            let data = try JSONSerialization.data(withJSONObject: profileDict)
            return try? JSONDecoder().decode(UserProfile.self, from: data)
        }
        return nil
    }

    // MARK: - Search

    func search(keywords: String, limit: Int = 30, offset: Int = 0) async throws -> [APISong] {
        let resp = try await client.cloudsearch(keywords: keywords, type: .single, limit: limit, offset: offset)
        let r: SearchResponse = try decodeResponse(resp)
        return r.result?.songs ?? []
    }

    func hotSearch(forceRefresh: Bool = false) async throws -> [HotSearchItem] {
        let cacheKey = "hot_search"
        if !forceRefresh, let cached: [HotSearchItem] = await APICache.shared.get(cacheKey) {
            return cached
        }
        let resp = try await client.searchHotDetail()
        let r: HotSearchResponse = try decodeResponse(resp)
        let res = r.data ?? []
        await APICache.shared.set(cacheKey, value: res, ttl: 300)
        return res
    }

    // MARK: - Song URL（直连解析 + 智能解灰 + 音频规格提取，破解 VIP 30s/45s 试听限制）

    func songURL(id: Int, level: String = "exhigh") async throws -> String? {
        let (url, _) = try await songURLWithSpec(id: id, level: level)
        return url
    }

    func songURLWithSpec(id: Int, level: String = "exhigh") async throws -> (url: String?, spec: AudioQualitySpec) {
        let qualityLevel: SoundQualityType
        switch level {
        case "standard": qualityLevel = .standard
        case "lossless": qualityLevel = .lossless
        case "hires": qualityLevel = .hires
        default: qualityLevel = .exhigh
        }

        let resp = try await client.songUrlV1(ids: [id], level: qualityLevel)
        var firstData: [String: Any]? = nil
        if let dataList = resp.body["data"] as? [[String: Any]],
           let first = dataList.first {
            firstData = first
        }

        var rawUrlString = firstData?["url"] as? String ?? ""

        // 解析真实音频规格参数
        let br = firstData?["br"] as? Int ?? (qualityLevel == .hires ? 1411200 : (qualityLevel == .lossless ? 850000 : 320000))
        let size = (firstData?["size"] as? Int64) ?? Int64((firstData?["size"] as? Int) ?? 0)
        let rawType = (firstData?["type"] as? String)?.uppercased()
        let actualLevel = (firstData?["level"] as? String) ?? level
        let format = rawType ?? ((actualLevel == "hires" || actualLevel == "lossless") ? "FLAC" : "MP3")

        var sampleRate = 44100
        var bitDepth = 16
        if actualLevel == "hires" || actualLevel == "jymaster" || br >= 1000000 {
            bitDepth = 24
            sampleRate = 96000
        } else if actualLevel == "lossless" || format == "FLAC" {
            bitDepth = 16
            sampleRate = 44100
        } else {
            sampleRate = 44100
            bitDepth = 16
        }

        var spec = AudioQualitySpec(
            level: actualLevel,
            format: format,
            bitrate: br,
            sampleRate: sampleRate,
            bitDepth: bitDepth,
            size: size
        )

        // 检测是否为 VIP 试听片段或无可用链接
        let freeTime = firstData?["freeTimeTrialPrivilege"] as? [String: Any]
        let remainTime = freeTime?["remainTime"] as? Int ?? 0
        let hasTrialInfo = firstData?["freeTrialInfo"] != nil && !(firstData?["freeTrialInfo"] is NSNull)
        let isSnippet = (remainTime > 0) || hasTrialInfo || rawUrlString.isEmpty

        // 智能解灰：如果检测到试听或空链接，使用 GD音乐台等音源匹配全曲完整音频
        if isSnippet && autoUnblockEnabled {
            #if DEBUG
            print("🔓 [glMusic] 检测到 VIP 限制或试听片段 (id: \(id), remainTime: \(remainTime)s)，启动智能换源...")
            #endif
            if let unblocked = await unblockManager.match(id: id, quality: "320"), !unblocked.url.isEmpty {
                #if DEBUG
                print("🎉 [glMusic] 智能换源成功！已匹配全曲 320k 完整音源: \(unblocked.platform)")
                #endif
                rawUrlString = unblocked.url
                spec = AudioQualitySpec(level: "exhigh", format: "MP3", bitrate: 320000, sampleRate: 44100, bitDepth: 16, size: 0)
            }
        }

        // 回退机制：若仍为空，尝试标准码率 songUrl
        if rawUrlString.isEmpty {
            if let fallbackResp = try? await client.songUrl(ids: [id], br: 320000),
               let dataList = fallbackResp.body["data"] as? [[String: Any]],
               let first = dataList.first,
               let fallbackUrl = first["url"] as? String, !fallbackUrl.isEmpty {
                rawUrlString = fallbackUrl
                spec = AudioQualitySpec(level: "exhigh", format: "MP3", bitrate: 320000, sampleRate: 44100, bitDepth: 16, size: 0)
            }
        }

        return (normalizeAudioURL(rawUrlString), spec)
    }

    /// 灰色歌曲直接获取链接（GD音乐台等音源匹配）
    func songURLMatch(id: Int) async throws -> String? {
        if let unblocked = await unblockManager.match(id: id, quality: "320"), !unblocked.url.isEmpty {
            return normalizeAudioURL(unblocked.url)
        }
        return nil
    }

    /// 将经过验证支持 HTTPS 的音频域名升级为 https://，以符合系统 ATS 安全策略
    private func normalizeAudioURL(_ urlStr: String?) -> String? {
        guard let urlStr = urlStr, !urlStr.isEmpty else { return nil }
        guard let url = URL(string: urlStr), let host = url.host?.lowercased() else { return urlStr }

        // 经测试验证，*.music.126.net 泛域名全系支持有效 TLS 1.3 / DigiCert SSL 证书
        if url.scheme?.lowercased() == "http" && (host.hasSuffix(".music.126.net") || host == "music.126.net") {
            var comp = URLComponents(url: url, resolvingAgainstBaseURL: false)
            comp?.scheme = "https"
            return comp?.string ?? urlStr.replacingOccurrences(of: "http://", with: "https://")
        }
        return urlStr
    }

    func songDetail(ids: [Int]) async throws -> [APISong] {
        guard !ids.isEmpty else { return [] }
        let resp = try await client.songDetail(ids: ids)
        let r: SongDetailResponse = try decodeResponse(resp)
        return r.songs ?? []
    }

    // MARK: - Lyrics

    func lyrics(id: Int) async throws -> LyricResponse {
        let cacheKey = "lyrics_new_\(id)"
        if let cached: LyricResponse = await APICache.shared.get(cacheKey) {
            return cached
        }
        do {
            let resp = try await client.lyricNew(id: id)
            let res: LyricResponse = try decodeResponse(resp)
            await APICache.shared.set(cacheKey, value: res, ttl: 1800) // 歌词缓存30分钟
            return res
        } catch {
            let fallbackResp = try await client.lyric(id: id)
            let fallback: LyricResponse = try decodeResponse(fallbackResp)
            await APICache.shared.set(cacheKey, value: fallback, ttl: 1800)
            return fallback
        }
    }

    // MARK: - Recommendations (带内存缓存)

    func personalizedPlaylists(limit: Int = 10, forceRefresh: Bool = false) async throws -> [APIPlaylist] {
        let cacheKey = "personalized_playlists_\(limit)"
        if !forceRefresh, let cached: [APIPlaylist] = await APICache.shared.get(cacheKey) {
            return cached
        }
        let resp = try await client.personalized(limit: limit)
        let r: PersonalizedResponse = try decodeResponse(resp)
        let res = r.result ?? []
        await APICache.shared.set(cacheKey, value: res, ttl: 300) // 缓存5分钟
        return res
    }

    // MARK: - Official Playlists (歌单广场 - 官方歌单)

    func officialPlaylists(cat: String = "精选", limit: Int = 60, offset: Int = 0, forceRefresh: Bool = false) async throws -> [APIPlaylist] {
        if cat == "精选" || cat == "全部" {
            let cacheKey = "official_playlists_\(cat)_\(limit)_\(offset)"
            if !forceRefresh, let cached: [APIPlaylist] = await APICache.shared.get(cacheKey) {
                return cached
            }
            // 网易云官方歌单账号 (UID: 1463586082 为云音乐官方歌单)
            let resp = try await client.userPlaylist(uid: 1463586082, limit: limit, offset: offset)
            let r: UserPlaylistResponse = try decodeResponse(resp)
            var res = r.playlist ?? []
            res = res.filter { $0.id != 0 }
            await APICache.shared.set(cacheKey, value: res, ttl: 300)
            return res
        } else {
            let cacheKey = "official_cat_playlists_\(cat)_\(limit)_\(offset)"
            if !forceRefresh, let cached: [APIPlaylist] = await APICache.shared.get(cacheKey) {
                return cached
            }
            // 分类歌单从 /top/playlist 获取并严格过滤只保留官方歌单
            let resp = try await client.topPlaylist(cat: cat, limit: max(limit, 50), offset: offset)
            let r: TopPlaylistResponse = try decodeResponse(resp)
            let list = r.playlists ?? []
            let res = list.filter { $0.isOfficial }
            await APICache.shared.set(cacheKey, value: res, ttl: 300)
            return res
        }
    }

    func playlistHotTags(forceRefresh: Bool = false) async throws -> [APIPlaylistTag] {
        let cacheKey = "playlist_hot_tags"
        if !forceRefresh, let cached: [APIPlaylistTag] = await APICache.shared.get(cacheKey) {
            return cached
        }
        let resp = try await client.playlistHot()
        let r: PlaylistHotTagsResponse = try decodeResponse(resp)
        let res = r.tags ?? []
        await APICache.shared.set(cacheKey, value: res, ttl: 600)
        return res
    }

    func personalizedNewSongs(forceRefresh: Bool = false) async throws -> [NewSongWrapper] {
        let cacheKey = "personalized_newsongs"
        if !forceRefresh, let cached: [NewSongWrapper] = await APICache.shared.get(cacheKey) {
            return cached
        }
        let resp = try await client.personalizedNewsong(limit: 10)
        let r: PersonalizedNewSongResponse = try decodeResponse(resp)
        let res = r.result ?? []
        await APICache.shared.set(cacheKey, value: res, ttl: 300) // 缓存5分钟
        return res
    }

    // MARK: - Banner (带内存缓存)

    func banner(forceRefresh: Bool = false) async throws -> [APIBanner] {
        let cacheKey = "banners"
        if !forceRefresh, let cached: [APIBanner] = await APICache.shared.get(cacheKey) {
            return cached
        }
        let resp = try await client.banner(type: .pc)
        let r: BannerResponse = try decodeResponse(resp)
        let res = r.banners ?? []
        await APICache.shared.set(cacheKey, value: res, ttl: 300) // 缓存5分钟
        return res
    }

    // MARK: - Playlist (带内存缓存)

    func playlistDetail(id: Int, forceRefresh: Bool = false) async throws -> APIPlaylist? {
        let cacheKey = "playlist_detail_\(id)"
        if !forceRefresh, let cached: APIPlaylist = await APICache.shared.get(cacheKey) {
            return cached
        }
        let resp = try await client.playlistDetail(id: id)
        let r: PlaylistDetailFullResponse = try decodeResponse(resp)
        if let pl = r.playlist {
            await APICache.shared.set(cacheKey, value: pl, ttl: 300)
        }
        return r.playlist
    }

    func playlistTracks(id: Int, limit: Int = 50, offset: Int = 0, forceRefresh: Bool = false) async throws -> [APISong] {
        let cacheKey = "playlist_tracks_\(id)_\(limit)_\(offset)"
        if !forceRefresh, let cached: [APISong] = await APICache.shared.get(cacheKey) {
            return cached
        }
        let resp = try await client.playlistTrackAll(id: id, limit: limit, offset: offset)
        let r: PlaylistTracksResponse = try decodeResponse(resp)
        let res = r.songs ?? []
        await APICache.shared.set(cacheKey, value: res, ttl: 300)
        return res
    }

    // MARK: - Artists (带内存缓存)

    func topArtists(limit: Int = 30, forceRefresh: Bool = false) async throws -> [APIArtistDetail] {
        let cacheKey = "top_artists_\(limit)"
        if !forceRefresh, let cached: [APIArtistDetail] = await APICache.shared.get(cacheKey) {
            return cached
        }
        let resp = try await client.topArtists(limit: limit)
        let r: TopArtistsResponse = try decodeResponse(resp)
        let res = r.artists ?? []
        await APICache.shared.set(cacheKey, value: res, ttl: 600) // 缓存10分钟
        return res
    }

    func artistDetail(id: Int, forceRefresh: Bool = false) async throws -> ArtistDetailResponse {
        let cacheKey = "artist_detail_\(id)"
        if !forceRefresh, let cached: ArtistDetailResponse = await APICache.shared.get(cacheKey) {
            return cached
        }
        let resp = try await client.artists(id: id)
        let res: ArtistDetailResponse = try decodeResponse(resp)
        await APICache.shared.set(cacheKey, value: res, ttl: 600)
        return res
    }

    func artistAlbums(id: Int, limit: Int = 30, forceRefresh: Bool = false) async throws -> [APIAlbumDetail] {
        let cacheKey = "artist_albums_\(id)_\(limit)"
        if !forceRefresh, let cached: [APIAlbumDetail] = await APICache.shared.get(cacheKey) {
            return cached
        }
        let resp = try await client.artistAlbum(id: id, limit: limit)
        let r: ArtistAlbumResponse = try decodeResponse(resp)
        let res = r.hotAlbums ?? []
        await APICache.shared.set(cacheKey, value: res, ttl: 600)
        return res
    }

    // MARK: - Daily Recommend Songs

    func dailyRecommendSongs(forceRefresh: Bool = false) async throws -> [APISong] {
        let cacheKey = "daily_recommend_songs"
        if !forceRefresh, let cached: [APISong] = await APICache.shared.get(cacheKey) {
            return cached
        }
        let resp = try await client.recommendSongs()
        let r: DailySongsResponse = try decodeResponse(resp)
        let res = r.data?.dailySongs ?? []
        await APICache.shared.set(cacheKey, value: res, ttl: 600)
        return res
    }

    // MARK: - Personal FM (私人 FM)

    func personalFm() async throws -> [APISong] {
        let resp = try await client.personalFm()
        let r: PersonalFmResponse = try decodeResponse(resp)
        return r.data ?? []
    }

    func fmTrash(id: Int, alg: String = "RT", time: Int = 25) async throws -> Bool {
        let resp = try await client.fmTrash(id: id, alg: alg, time: time)
        let r: BaseAPIResponse = try decodeResponse(resp)
        return (r.code == 200)
    }

    // MARK: - Similar Songs & Infinite Roaming (相似歌曲与心动模式漫游)

    func simiSongs(id: Int, limit: Int = 30) async throws -> [APISong] {
        let cacheKey = "simi_songs_\(id)"
        if let cached: [APISong] = await APICache.shared.get(cacheKey) {
            return cached
        }
        let resp = try await client.simiSong(id: id, limit: limit)
        let r: SimiSongResponse = try decodeResponse(resp)
        let res = r.songs ?? []
        await APICache.shared.set(cacheKey, value: res, ttl: 300)
        return res
    }

    func intelligenceList(id: Int, playlistId: Int, count: Int = 20) async throws -> [APISong] {
        let resp = try await client.playmodeIntelligenceList(id: id, pid: playlistId, sid: id, count: count)
        let r: IntelligenceListResponse = try decodeResponse(resp)
        let res = (r.data ?? []).compactMap(\.resolvedSong)
        return res
    }

    /// 根据给定的种子歌曲和上下文歌单，自动获取高质量相似流歌曲 (去除已在播放列表中的歌曲)
    func fetchInfiniteRoamingSongs(seedSong: APISong, playlistId: Int? = nil, excludeSongIds: Set<Int> = []) async -> [APISong] {
        var results: [APISong] = []

        // 1. 如果有歌单上下文，优先尝试心动模式智能算法
        if let pid = playlistId, pid > 0 {
            if let list = try? await intelligenceList(id: seedSong.id, playlistId: pid), !list.isEmpty {
                results = list
            }
        }

        // 2. 如果无歌单上下文或智能接口未返回，尝试相似歌曲推荐
        if results.isEmpty {
            if let list = try? await simiSongs(id: seedSong.id, limit: 30), !list.isEmpty {
                results = list
            }
        }

        // 3. 兜底保障：若冷门歌曲无相似歌曲，请求每日推荐补充，确保无限流「永不停止」
        if results.isEmpty {
            if let daily = try? await dailyRecommendSongs(), !daily.isEmpty {
                results = daily.shuffled()
            }
        }

        // 过滤已存在歌曲和种子本身
        var seen = excludeSongIds
        seen.insert(seedSong.id)
        var filtered: [APISong] = []
        for s in results {
            if !seen.contains(s.id) {
                seen.insert(s.id)
                filtered.append(s)
            }
        }

        return filtered
    }

    // MARK: - Like Song

    func likeSong(id: Int, like: Bool = true) async throws -> Bool {
        let resp = try await client.like(id: id, like: like)
        let r: BaseAPIResponse = try decodeResponse(resp)
        return r.code == 200
    }

    func likeList(uid: Int) async throws -> [Int] {
        let resp = try await client.likelist(uid: uid)
        let r: LikeListResponse = try decodeResponse(resp)
        return r.ids ?? []
    }

    // MARK: - Albums (带内存缓存)

    func newAlbums(limit: Int = 30, forceRefresh: Bool = false) async throws -> [APIAlbumDetail] {
        let cacheKey = "new_albums_\(limit)"
        if !forceRefresh, let cached: [APIAlbumDetail] = await APICache.shared.get(cacheKey) {
            return cached
        }
        let resp = try await client.albumNew(area: .zh, limit: limit)
        let r: NewAlbumsResponse = try decodeResponse(resp)
        let res = r.albums ?? []
        await APICache.shared.set(cacheKey, value: res, ttl: 600)
        return res
    }

    func albumDetail(id: Int, forceRefresh: Bool = false) async throws -> AlbumDetailResponse {
        let cacheKey = "album_detail_\(id)"
        if !forceRefresh, let cached: AlbumDetailResponse = await APICache.shared.get(cacheKey) {
            return cached
        }
        let resp = try await client.album(id: id)
        let res: AlbumDetailResponse = try decodeResponse(resp)
        await APICache.shared.set(cacheKey, value: res, ttl: 600)
        return res
    }

    // MARK: - Toplist (带内存缓存)

    func toplist(forceRefresh: Bool = false) async throws -> [APIPlaylist] {
        let cacheKey = "toplist"
        if !forceRefresh, let cached: [APIPlaylist] = await APICache.shared.get(cacheKey) {
            return cached
        }
        let resp = try await client.toplist()
        let r: ToplistResponse = try decodeResponse(resp)
        let res = r.list ?? []
        await APICache.shared.set(cacheKey, value: res, ttl: 600)
        return res
    }

    // MARK: - User Playlists

    func userPlaylists(uid: Int, limit: Int = 50, forceRefresh: Bool = false) async throws -> [APIPlaylist] {
        let cacheKey = "user_playlists_\(uid)_\(limit)"
        if !forceRefresh, let cached: [APIPlaylist] = await APICache.shared.get(cacheKey) {
            return cached
        }
        let resp = try await client.userPlaylist(uid: uid, limit: limit)
        let r: UserPlaylistResponse = try decodeResponse(resp)
        let res = r.playlist ?? []
        await APICache.shared.set(cacheKey, value: res, ttl: 180)
        return res
    }

    // MARK: - DJ Radio (广播 / 电台 / 播客，带内存缓存)

    func djBanners(forceRefresh: Bool = false) async throws -> [APIDJBanner] {
        let cacheKey = "dj_banners"
        if !forceRefresh, let cached: [APIDJBanner] = await APICache.shared.get(cacheKey) {
            return cached
        }
        let resp = try await client.djBanner()
        let r: DJBannerResponse = try decodeResponse(resp)
        let res = r.data ?? []
        await APICache.shared.set(cacheKey, value: res, ttl: 300)
        return res
    }

    func djRecommend(forceRefresh: Bool = false) async throws -> [APIDJRadio] {
        let cacheKey = "dj_recommend"
        if !forceRefresh, let cached: [APIDJRadio] = await APICache.shared.get(cacheKey) {
            return cached
        }
        let resp = try await client.djRecommend()
        let r: DJRecommendResponse = try decodeResponse(resp)
        let res = r.djRadios ?? []
        await APICache.shared.set(cacheKey, value: res, ttl: 300)
        return res
    }

    func djProgramToplist(limit: Int = 10, forceRefresh: Bool = false) async throws -> [APIDJToplistItem] {
        let cacheKey = "dj_program_toplist_\(limit)"
        if !forceRefresh, let cached: [APIDJToplistItem] = await APICache.shared.get(cacheKey) {
            return cached
        }
        let resp = try await client.djProgramToplist(limit: limit)
        let r: DJProgramToplistResponse = try decodeResponse(resp)
        let res = r.toplist ?? []
        await APICache.shared.set(cacheKey, value: res, ttl: 300)
        return res
    }

    func djCategories(forceRefresh: Bool = false) async throws -> [APIDJCategory] {
        let cacheKey = "dj_categories"
        if !forceRefresh, let cached: [APIDJCategory] = await APICache.shared.get(cacheKey) {
            return cached
        }
        let resp = try await client.djCatelist()
        let r: DJCategoryResponse = try decodeResponse(resp)
        let res = r.categories ?? []
        await APICache.shared.set(cacheKey, value: res, ttl: 1800)
        return res
    }

    func djRadiosByCategory(typeId: Int, forceRefresh: Bool = false) async throws -> [APIDJRadio] {
        let cacheKey = "dj_radios_category_\(typeId)"
        if !forceRefresh, let cached: [APIDJRadio] = await APICache.shared.get(cacheKey) {
            return cached
        }
        let resp = try await client.djRecommendType(cateId: typeId)
        let r: DJRecommendResponse = try decodeResponse(resp)
        let res = r.djRadios ?? []
        await APICache.shared.set(cacheKey, value: res, ttl: 300)
        return res
    }

    func djRadioDetail(rid: Int, forceRefresh: Bool = false) async throws -> APIDJRadio? {
        let cacheKey = "dj_radio_detail_\(rid)"
        if !forceRefresh, let cached: APIDJRadio = await APICache.shared.get(cacheKey) {
            return cached
        }
        let resp = try await client.djDetail(rid: rid)
        let r: DJDetailResponse = try decodeResponse(resp)
        if let d = r.data {
            await APICache.shared.set(cacheKey, value: d, ttl: 300)
        }
        return r.data
    }

    func djRadioPrograms(rid: Int, limit: Int = 50, offset: Int = 0, forceRefresh: Bool = false) async throws -> [APIDJProgram] {
        let cacheKey = "dj_programs_\(rid)_\(limit)_\(offset)"
        if !forceRefresh, let cached: [APIDJProgram] = await APICache.shared.get(cacheKey) {
            return cached
        }
        let resp = try await client.djProgram(rid: rid, limit: limit, offset: offset)
        let r: DJProgramResponse = try decodeResponse(resp)
        let res = r.programs ?? []
        await APICache.shared.set(cacheKey, value: res, ttl: 300)
        return res
    }

    func djProgramDetail(id: Int) async throws -> APIDJProgram? {
        let resp = try await client.djProgramDetail(id: id)
        let r: DJProgramDetailResponse = try decodeResponse(resp)
        return r.program
    }

    // MARK: - Error

    enum APIError: Error, LocalizedError {
        case invalidURL
        case serverError(statusCode: Int)
        case networkUnreachable
        case timeout
        case decodingFailed(underlying: Error)
        case noData

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "无效的网络地址"
            case .serverError(let code):
                return "服务器响应异常 (状态码: \(code))"
            case .networkUnreachable:
                return "网络连接失败，请检查您的网络连接"
            case .timeout:
                return "网络请求超时，请检查服务响应"
            case .decodingFailed:
                return "数据解析异常"
            case .noData:
                return "未获取到有效数据"
            }
        }
    }
}
