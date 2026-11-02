//
//  NetworkManager.swift
//  glMusic
//
//  Created by go love on 10/23/26.
//

import Foundation

final class NetworkManager {
    static let shared = NetworkManager()

    private let baseURL = "http://127.0.0.1:3000"

    // MARK: - Cookie 管理

    var cookie: String? {
        get { UserDefaults.standard.string(forKey: "netease_cookie") }
        set { UserDefaults.standard.set(newValue, forKey: "netease_cookie") }
    }

    var isLoggedIn: Bool { cookie != nil && !cookie!.isEmpty }

    func logout() { cookie = nil }

    // MARK: - 通用请求（自动带 Cookie + randomCNIP）

    private func request<T: Codable>(_ path: String, params: [String: String] = [:]) async throws -> T {
        var components = URLComponents(string: baseURL + path)!
        var items = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        items.append(URLQueryItem(name: "timestamp", value: "\(Int(Date().timeIntervalSince1970 * 1000))"))
        items.append(URLQueryItem(name: "randomCNIP", value: "true"))
        // 通过 query 参数传递 cookie（NeteaseCloudMusicApi 标准方式）
        if let cookie = cookie {
            items.append(URLQueryItem(name: "cookie", value: cookie))
        }
        components.queryItems = items

        guard let url = components.url else { throw APIError.invalidURL }

        var req = URLRequest(url: url)
        if let cookie = cookie {
            req.setValue(cookie, forHTTPHeaderField: "Cookie")
        }

        let (data, response) = try await URLSession.shared.data(for: req)

        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw APIError.serverError
        }

        return try JSONDecoder().decode(T.self, from: data)
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

    func hotSearch() async throws -> [HotSearchItem] {
        let r: HotSearchResponse = try await request("/search/hot/detail")
        return r.data ?? []
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
        let r: SongDetailResponse = try await request("/song/detail", params: [
            "ids": ids.map(String.init).joined(separator: ",")
        ])
        return r.songs ?? []
    }

    // MARK: - Lyrics

    func lyrics(id: Int) async throws -> LyricResponse {
        try await request("/lyric", params: ["id": "\(id)"])
    }

    // MARK: - Recommendations

    func personalizedPlaylists(limit: Int = 10) async throws -> [APIPlaylist] {
        let r: PersonalizedResponse = try await request("/personalized", params: ["limit": "\(limit)"])
        return r.result ?? []
    }

    func personalizedNewSongs() async throws -> [NewSongWrapper] {
        let r: PersonalizedNewSongResponse = try await request("/personalized/newsong")
        return r.result ?? []
    }

    // MARK: - Banner

    func banner() async throws -> [APIBanner] {
        let r: BannerResponse = try await request("/banner", params: ["type": "0"])
        return r.banners ?? []
    }

    // MARK: - Playlist

    func playlistDetail(id: Int) async throws -> APIPlaylist? {
        let r: PlaylistDetailFullResponse = try await request("/playlist/detail", params: ["id": "\(id)"])
        return r.playlist
    }

    func playlistTracks(id: Int, limit: Int = 50, offset: Int = 0) async throws -> [APISong] {
        let r: PlaylistTracksResponse = try await request("/playlist/track/all", params: [
            "id": "\(id)", "limit": "\(limit)", "offset": "\(offset)"
        ])
        return r.songs ?? []
    }

    // MARK: - Artists

    func topArtists(limit: Int = 30) async throws -> [APIArtistDetail] {
        let r: TopArtistsResponse = try await request("/top/artists", params: ["limit": "\(limit)"])
        return r.artists ?? []
    }

    func artistDetail(id: Int) async throws -> ArtistDetailResponse {
        try await request("/artists", params: ["id": "\(id)"])
    }

    func artistAlbums(id: Int, limit: Int = 30) async throws -> [APIAlbumDetail] {
        let r: ArtistAlbumResponse = try await request("/artist/album", params: ["id": "\(id)", "limit": "\(limit)"])
        return r.hotAlbums ?? []
    }

    // MARK: - Daily Recommend Songs

    func dailyRecommendSongs() async throws -> [APISong] {
        let r: DailySongsResponse = try await request("/recommend/songs")
        return r.data?.dailySongs ?? []
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

    // MARK: - Albums

    func newAlbums(limit: Int = 30) async throws -> [APIAlbumDetail] {
        let r: NewAlbumsResponse = try await request("/album/new", params: [
            "area": "ZH", "limit": "\(limit)"
        ])
        return r.albums ?? []
    }

    func albumDetail(id: Int) async throws -> AlbumDetailResponse {
        try await request("/album", params: ["id": "\(id)"])
    }

    // MARK: - Toplist

    func toplist() async throws -> [APIPlaylist] {
        let r: ToplistResponse = try await request("/toplist")
        return r.list ?? []
    }

    // MARK: - User Playlists

    func userPlaylists(uid: Int, limit: Int = 50) async throws -> [APIPlaylist] {
        let r: UserPlaylistResponse = try await request("/user/playlist", params: [
            "uid": "\(uid)", "limit": "\(limit)"
        ])
        return r.playlist ?? []
    }

    // MARK: - DJ Radio (广播 / 电台 / 播客)

    func djBanners() async throws -> [APIDJBanner] {
        let r: DJBannerResponse = try await request("/dj/banner")
        return r.data ?? []
    }

    func djRecommend() async throws -> [APIDJRadio] {
        let r: DJRecommendResponse = try await request("/dj/recommend")
        return r.djRadios ?? []
    }

    func djProgramToplist(limit: Int = 10) async throws -> [APIDJToplistItem] {
        let r: DJProgramToplistResponse = try await request("/dj/program/toplist", params: ["limit": "\(limit)"])
        return r.toplist ?? []
    }

    func djCategories() async throws -> [APIDJCategory] {
        let r: DJCategoryResponse = try await request("/dj/catelist")
        return r.categories ?? []
    }

    func djRadiosByCategory(typeId: Int) async throws -> [APIDJRadio] {
        let r: DJRecommendResponse = try await request("/dj/recommend/type", params: ["type": "\(typeId)"])
        return r.djRadios ?? []
    }

    func djRadioDetail(rid: Int) async throws -> APIDJRadio? {
        let r: DJDetailResponse = try await request("/dj/detail", params: ["rid": "\(rid)"])
        return r.data
    }

    func djRadioPrograms(rid: Int, limit: Int = 50, offset: Int = 0) async throws -> [APIDJProgram] {
        let r: DJProgramResponse = try await request("/dj/program", params: [
            "rid": "\(rid)", "limit": "\(limit)", "offset": "\(offset)"
        ])
        return r.programs ?? []
    }

    func djProgramDetail(id: Int) async throws -> APIDJProgram? {
        let r: DJProgramDetailResponse = try await request("/dj/program/detail", params: ["id": "\(id)"])
        return r.program
    }

    // MARK: - Error

    enum APIError: Error, LocalizedError {
        case invalidURL, serverError, noData
        var errorDescription: String? {
            switch self {
            case .invalidURL:   return "无效的 URL"
            case .serverError:  return "服务器错误"
            case .noData:       return "无数据"
            }
        }
    }
}
