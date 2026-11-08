//
//  NetworkManager.swift
//  glMusic
//
//  Created by go love on 10/23/26.
//

import Foundation

// MARK: - API Cache Layer

actor APICache {
    static let shared = APICache()

    private struct CacheEntry {
        let data: Any
        let expiration: Date
    }

    private var storage: [String: CacheEntry] = [:]

    func get<T>(_ key: String) -> T? {
        guard let entry = storage[key] else { return nil }
        if Date() < entry.expiration {
            return entry.data as? T
        } else {
            storage.removeValue(forKey: key)
            return nil
        }
    }

    func set<T>(_ key: String, value: T, ttl: TimeInterval) {
        storage[key] = CacheEntry(data: value, expiration: Date().addingTimeInterval(ttl))
    }

    func remove(_ key: String) {
        storage.removeValue(forKey: key)
    }

    func clearAll() {
        storage.removeAll()
    }
}

// MARK: - Network Manager

final class NetworkManager: @unchecked Sendable {
    static let shared = NetworkManager()

    private let baseURL = "http://127.0.0.1:3000"

    // MARK: - Cache Invalidation

    func clearCache() async {
        await APICache.shared.clearAll()
    }

    // MARK: - Cookie 管理

    var cookie: String? {
        get { UserDefaults.standard.string(forKey: "netease_cookie") }
        set { UserDefaults.standard.set(newValue, forKey: "netease_cookie") }
    }

    var isLoggedIn: Bool { cookie != nil && !cookie!.isEmpty }

    func logout() {
        cookie = nil
        Task { await clearCache() }
    }

    // MARK: - 通用请求（带重试 + 自动 Cookie + randomCNIP + 优雅错误处理）

    private func request<T: Codable>(_ path: String, params: [String: String] = [:], maxRetries: Int = 1) async throws -> T {
        var lastError: Error = APIError.serverError(statusCode: 500)
        for attempt in 0...maxRetries {
            do {
                return try await executeRequest(path, params: params)
            } catch let err as URLError where err.code == .cancelled {
                throw err
            } catch {
                lastError = error
                if attempt < maxRetries {
                    try? await Task.sleep(for: .milliseconds(400 * (attempt + 1)))
                    continue
                }
            }
        }
        throw lastError
    }

    private func executeRequest<T: Codable>(_ path: String, params: [String: String] = [:]) async throws -> T {
        guard var components = URLComponents(string: baseURL + path) else {
            throw APIError.invalidURL
        }
        var items = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        items.append(URLQueryItem(name: "timestamp", value: "\(Int(Date().timeIntervalSince1970 * 1000))"))
        items.append(URLQueryItem(name: "randomCNIP", value: "true"))
        if let cookie = cookie {
            items.append(URLQueryItem(name: "cookie", value: cookie))
        }
        components.queryItems = items

        guard let url = components.url else { throw APIError.invalidURL }

        var req = URLRequest(url: url)
        req.timeoutInterval = 15
        if let cookie = cookie {
            req.setValue(cookie, forHTTPHeaderField: "Cookie")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: req)
        } catch let urlErr as URLError {
            if urlErr.code == .notConnectedToInternet || urlErr.code == .networkConnectionLost {
                throw APIError.networkUnreachable
            } else if urlErr.code == .timedOut {
                throw APIError.timeout
            }
            throw urlErr
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.serverError(statusCode: -1)
        }
        guard (200...299).contains(http.statusCode) else {
            throw APIError.serverError(statusCode: http.statusCode)
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError.decodingFailed(underlying: error)
        }
    }

    // MARK: - 游客登录（获取基础 Cookie）

    func registerAnonymous() async throws {
        struct AnonResponse: Codable { let cookie: String?; let code: Int? }
        let r: AnonResponse = try await request("/register/anonimous")
        if let c = r.cookie { cookie = c }
    }

    // MARK: - 二维码登录

    func getQRKey() async throws -> String {
        let r: QRKeyResponse = try await request("/login/qr/key", params: ["noCookie": "true"])
        guard let key = r.data?.unikey else { throw APIError.noData }
        return key
    }

    func createQR(key: String) async throws -> String {
        let r: QRCreateResponse = try await request("/login/qr/create", params: [
            "key": key, "qrimg": "true", "noCookie": "true"
        ])
        guard let img = r.data?.qrimg else { throw APIError.noData }
        return img
    }

    func checkQR(key: String) async throws -> QRCheckResponse {
        try await request("/login/qr/check", params: ["key": key, "noCookie": "true"])
    }

    // MARK: - 短信验证码登录

    func sendCaptcha(phone: String) async throws {
        struct R: Codable { let code: Int?; let data: Bool? }
        let _: R = try await request("/captcha/sent", params: ["phone": phone])
    }

    func loginWithCaptcha(phone: String, captcha: String) async throws -> String? {
        struct LoginResponse: Codable { let code: Int?; let cookie: String?; let message: String? }
        let r: LoginResponse = try await request("/login/cellphone", params: [
            "phone": phone, "captcha": captcha
        ])
        if let c = r.cookie { cookie = c }
        return r.cookie
    }

    // MARK: - 登录状态

    func loginStatus() async throws -> UserProfile? {
        let r: LoginStatusResponse = try await request("/login/status")
        return r.data?.profile
    }

    // MARK: - Search

    func search(keywords: String, limit: Int = 30, offset: Int = 0) async throws -> [APISong] {
        let r: SearchResponse = try await request("/cloudsearch", params: [
            "keywords": keywords, "type": "1", "limit": "\(limit)", "offset": "\(offset)"
        ])
        return r.result?.songs ?? []
    }

    func hotSearch(forceRefresh: Bool = false) async throws -> [HotSearchItem] {
        let cacheKey = "hot_search"
        if !forceRefresh, let cached: [HotSearchItem] = await APICache.shared.get(cacheKey) {
            return cached
        }
        let r: HotSearchResponse = try await request("/search/hot/detail")
        let res = r.data ?? []
        await APICache.shared.set(cacheKey, value: res, ttl: 300)
        return res
    }

    // MARK: - Song URL（带 unblock 解锁灰色歌曲）

    func songURL(id: Int, level: String = "exhigh") async throws -> String? {
        let r: SongURLResponse = try await request("/song/url/v1", params: [
            "id": "\(id)", "level": level, "unblock": "true"
        ])
        return normalizeAudioURL(r.data?.first?.url)
    }

    /// 灰色歌曲直接获取链接（UnblockNeteaseMusic）
    func songURLMatch(id: Int) async throws -> String? {
        let r: SongURLResponse = try await request("/song/url/match", params: ["id": "\(id)"])
        return normalizeAudioURL(r.data?.first?.url)
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
        let r: SongDetailResponse = try await request("/song/detail", params: [
            "ids": ids.map(String.init).joined(separator: ",")
        ])
        return r.songs ?? []
    }

    // MARK: - Lyrics

    func lyrics(id: Int) async throws -> LyricResponse {
        let cacheKey = "lyrics_new_\(id)"
        if let cached: LyricResponse = await APICache.shared.get(cacheKey) {
            return cached
        }
        do {
            let res: LyricResponse = try await request("/lyric/new", params: ["id": "\(id)"])
            await APICache.shared.set(cacheKey, value: res, ttl: 1800) // 歌词缓存30分钟
            return res
        } catch {
            let fallback: LyricResponse = try await request("/lyric", params: ["id": "\(id)"])
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
        let r: PersonalizedResponse = try await request("/personalized", params: ["limit": "\(limit)"])
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
            let r: UserPlaylistResponse = try await request("/user/playlist", params: [
                "uid": "1463586082",
                "limit": "\(limit)",
                "offset": "\(offset)"
            ])
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
            let r: TopPlaylistResponse = try await request("/top/playlist", params: [
                "cat": cat,
                "limit": "\(max(limit, 50))",
                "offset": "\(offset)"
            ])
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
        let r: PlaylistHotTagsResponse = try await request("/playlist/hot")
        let res = r.tags ?? []
        await APICache.shared.set(cacheKey, value: res, ttl: 600)
        return res
    }

    func personalizedNewSongs(forceRefresh: Bool = false) async throws -> [NewSongWrapper] {
        let cacheKey = "personalized_newsongs"
        if !forceRefresh, let cached: [NewSongWrapper] = await APICache.shared.get(cacheKey) {
            return cached
        }
        let r: PersonalizedNewSongResponse = try await request("/personalized/newsong")
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
        let r: BannerResponse = try await request("/banner", params: ["type": "0"])
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
        let r: PlaylistDetailFullResponse = try await request("/playlist/detail", params: ["id": "\(id)"])
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
        let r: PlaylistTracksResponse = try await request("/playlist/track/all", params: [
            "id": "\(id)", "limit": "\(limit)", "offset": "\(offset)"
        ])
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
        let r: TopArtistsResponse = try await request("/top/artists", params: ["limit": "\(limit)"])
        let res = r.artists ?? []
        await APICache.shared.set(cacheKey, value: res, ttl: 600) // 缓存10分钟
        return res
    }

    func artistDetail(id: Int, forceRefresh: Bool = false) async throws -> ArtistDetailResponse {
        let cacheKey = "artist_detail_\(id)"
        if !forceRefresh, let cached: ArtistDetailResponse = await APICache.shared.get(cacheKey) {
            return cached
        }
        let res: ArtistDetailResponse = try await request("/artists", params: ["id": "\(id)"])
        await APICache.shared.set(cacheKey, value: res, ttl: 600)
        return res
    }

    func artistAlbums(id: Int, limit: Int = 30, forceRefresh: Bool = false) async throws -> [APIAlbumDetail] {
        let cacheKey = "artist_albums_\(id)_\(limit)"
        if !forceRefresh, let cached: [APIAlbumDetail] = await APICache.shared.get(cacheKey) {
            return cached
        }
        let r: ArtistAlbumResponse = try await request("/artist/album", params: ["id": "\(id)", "limit": "\(limit)"])
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
        let r: DailySongsResponse = try await request("/recommend/songs")
        let res = r.data?.dailySongs ?? []
        await APICache.shared.set(cacheKey, value: res, ttl: 600)
        return res
    }

    // MARK: - Like Song

    func likeSong(id: Int, like: Bool = true) async throws -> Bool {
        let r: BaseAPIResponse = try await request("/like", params: [
            "id": "\(id)", "like": like ? "true" : "false"
        ])
        return r.code == 200
    }

    func likeList(uid: Int) async throws -> [Int] {
        let r: LikeListResponse = try await request("/likelist", params: ["uid": "\(uid)"])
        return r.ids ?? []
    }

    // MARK: - Albums (带内存缓存)

    func newAlbums(limit: Int = 30, forceRefresh: Bool = false) async throws -> [APIAlbumDetail] {
        let cacheKey = "new_albums_\(limit)"
        if !forceRefresh, let cached: [APIAlbumDetail] = await APICache.shared.get(cacheKey) {
            return cached
        }
        let r: NewAlbumsResponse = try await request("/album/new", params: [
            "area": "ZH", "limit": "\(limit)"
        ])
        let res = r.albums ?? []
        await APICache.shared.set(cacheKey, value: res, ttl: 600)
        return res
    }

    func albumDetail(id: Int, forceRefresh: Bool = false) async throws -> AlbumDetailResponse {
        let cacheKey = "album_detail_\(id)"
        if !forceRefresh, let cached: AlbumDetailResponse = await APICache.shared.get(cacheKey) {
            return cached
        }
        let res: AlbumDetailResponse = try await request("/album", params: ["id": "\(id)"])
        await APICache.shared.set(cacheKey, value: res, ttl: 600)
        return res
    }

    // MARK: - Toplist (带内存缓存)

    func toplist(forceRefresh: Bool = false) async throws -> [APIPlaylist] {
        let cacheKey = "toplist"
        if !forceRefresh, let cached: [APIPlaylist] = await APICache.shared.get(cacheKey) {
            return cached
        }
        let r: ToplistResponse = try await request("/toplist")
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
        let r: UserPlaylistResponse = try await request("/user/playlist", params: [
            "uid": "\(uid)", "limit": "\(limit)"
        ])
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
        let r: DJBannerResponse = try await request("/dj/banner")
        let res = r.data ?? []
        await APICache.shared.set(cacheKey, value: res, ttl: 300)
        return res
    }

    func djRecommend(forceRefresh: Bool = false) async throws -> [APIDJRadio] {
        let cacheKey = "dj_recommend"
        if !forceRefresh, let cached: [APIDJRadio] = await APICache.shared.get(cacheKey) {
            return cached
        }
        let r: DJRecommendResponse = try await request("/dj/recommend")
        let res = r.djRadios ?? []
        await APICache.shared.set(cacheKey, value: res, ttl: 300)
        return res
    }

    func djProgramToplist(limit: Int = 10, forceRefresh: Bool = false) async throws -> [APIDJToplistItem] {
        let cacheKey = "dj_program_toplist_\(limit)"
        if !forceRefresh, let cached: [APIDJToplistItem] = await APICache.shared.get(cacheKey) {
            return cached
        }
        let r: DJProgramToplistResponse = try await request("/dj/program/toplist", params: ["limit": "\(limit)"])
        let res = r.toplist ?? []
        await APICache.shared.set(cacheKey, value: res, ttl: 300)
        return res
    }

    func djCategories(forceRefresh: Bool = false) async throws -> [APIDJCategory] {
        let cacheKey = "dj_categories"
        if !forceRefresh, let cached: [APIDJCategory] = await APICache.shared.get(cacheKey) {
            return cached
        }
        let r: DJCategoryResponse = try await request("/dj/catelist")
        let res = r.categories ?? []
        await APICache.shared.set(cacheKey, value: res, ttl: 1800)
        return res
    }

    func djRadiosByCategory(typeId: Int, forceRefresh: Bool = false) async throws -> [APIDJRadio] {
        let cacheKey = "dj_radios_category_\(typeId)"
        if !forceRefresh, let cached: [APIDJRadio] = await APICache.shared.get(cacheKey) {
            return cached
        }
        let r: DJRecommendResponse = try await request("/dj/recommend/type", params: ["type": "\(typeId)"])
        let res = r.djRadios ?? []
        await APICache.shared.set(cacheKey, value: res, ttl: 300)
        return res
    }

    func djRadioDetail(rid: Int, forceRefresh: Bool = false) async throws -> APIDJRadio? {
        let cacheKey = "dj_radio_detail_\(rid)"
        if !forceRefresh, let cached: APIDJRadio = await APICache.shared.get(cacheKey) {
            return cached
        }
        let r: DJDetailResponse = try await request("/dj/detail", params: ["rid": "\(rid)"])
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
        let r: DJProgramResponse = try await request("/dj/program", params: [
            "rid": "\(rid)", "limit": "\(limit)", "offset": "\(offset)"
        ])
        let res = r.programs ?? []
        await APICache.shared.set(cacheKey, value: res, ttl: 300)
        return res
    }

    func djProgramDetail(id: Int) async throws -> APIDJProgram? {
        let r: DJProgramDetailResponse = try await request("/dj/program/detail", params: ["id": "\(id)"])
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
                return "网络连接失败，请确认本地网易云 API 服务 (127.0.0.1:3000) 已启动"
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
