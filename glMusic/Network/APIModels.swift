//
//  APIModels.swift
//  glMusic
//
//  Created by go love on 10/23/26.
//

import Foundation

// MARK: - Safe URL & Image Helpers

extension String {
    /// 确保图片与网络资源使用安全 HTTPS 协议，避免 macOS 沙盒 ATS 拦截
    var httpsURL: String {
        guard hasPrefix("http://") else { return self }
        return "https://" + dropFirst(7)
    }

    /// 识别网易云通用的占位人影/未上传头像默认图片（如 /0.jpg 或 5639395138885805）
    var isNetEasePlaceholderImage: Bool {
        contains("/0.jpg") || contains("5639395138885805")
    }
}

enum SafeURLHelper {
    /// 从多个候选图片链接中择优选用真实图片并转为安全 HTTPS 协议
    static func chooseImage(from candidates: [String?]) -> String? {
        let valid = candidates.compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        for c in valid where !c.isNetEasePlaceholderImage {
            return c.httpsURL
        }
        return valid.first?.httpsURL
    }
}

// MARK: - Song

struct APISong: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let ar: [APIArtistBrief]?
    let al: APIAlbumBrief?
    let dt: Int?                   // duration in ms

    init(id: Int, name: String, ar: [APIArtistBrief]?, al: APIAlbumBrief?, dt: Int?) {
        self.id = id
        self.name = name
        self.ar = ar
        self.al = al
        self.dt = dt
    }

    enum CodingKeys: String, CodingKey {
        case id, name, ar, artists, al, album, dt, duration
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        ar = try container.decodeIfPresent([APIArtistBrief].self, forKey: .ar)
            ?? container.decodeIfPresent([APIArtistBrief].self, forKey: .artists)
        al = try container.decodeIfPresent(APIAlbumBrief.self, forKey: .al)
            ?? container.decodeIfPresent(APIAlbumBrief.self, forKey: .album)
        dt = try container.decodeIfPresent(Int.self, forKey: .dt)
            ?? container.decodeIfPresent(Int.self, forKey: .duration)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(ar, forKey: .ar)
        try container.encodeIfPresent(al, forKey: .al)
        try container.encodeIfPresent(dt, forKey: .dt)
    }

    var displayArtist: String {
        let names = (ar ?? []).compactMap(\.name).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        return names.isEmpty ? "未知艺人" : names.joined(separator: " / ")
    }
    var displayAlbum: String { al?.name ?? "" }
    var coverUrl: String? { al?.picUrl?.httpsURL }
    var durationMs: Int { dt ?? 0 }

    var durationText: String {
        let s = durationMs / 1000
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: APISong, rhs: APISong) -> Bool { lhs.id == rhs.id }
}

struct APIArtistBrief: Codable, Identifiable, Hashable {
    let id: Int?
    let name: String?
    let picUrl: String?
    var img1v1Url: String? = nil

    var avatarUrl: String? {
        SafeURLHelper.chooseImage(from: [img1v1Url, picUrl])
    }
}

struct APIAlbumBrief: Codable, Identifiable, Hashable {
    let id: Int?
    let name: String?
    let picUrl: String?

    var coverUrl: String? {
        picUrl?.httpsURL
    }
}

// MARK: - Search

struct SearchResponse: Codable {
    let result: SearchResult?
    let code: Int?
}

struct SearchResult: Codable {
    let songs: [APISong]?
    let songCount: Int?
}

// MARK: - Song URL

struct SongURLResponse: Codable {
    let data: [SongURLData]?
    let code: Int?
}

struct SongURLData: Codable {
    let id: Int
    let url: String?
    let br: Int?
    let size: Int?
    let type: String?
}

// MARK: - Song Detail

struct SongDetailResponse: Codable {
    let songs: [APISong]?
    let code: Int?
}

// MARK: - Lyrics

struct LyricResponse: Codable {
    let lrc: LyricContent?
    let tlyric: LyricContent?
    let code: Int?
}

struct LyricContent: Codable {
    let lyric: String?
}

// MARK: - Parsed Lyric Line

struct LyricLine: Identifiable, Equatable {
    let id = UUID()
    let time: TimeInterval
    let text: String
    var translation: String? = nil
}

// MARK: - Playlist

struct APIPlaylist: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let coverImgUrl: String?
    let picUrl: String?
    let playCount: Int?
    let trackCount: Int?
    let userId: Int?
    let description: String?

    var displayCover: String? {
        (coverImgUrl ?? picUrl)?.httpsURL
    }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: APIPlaylist, rhs: APIPlaylist) -> Bool { lhs.id == rhs.id }
}

struct PersonalizedResponse: Codable {
    let result: [APIPlaylist]?
    let code: Int?
}

struct PlaylistTracksResponse: Codable {
    let songs: [APISong]?
    let code: Int?
}

struct PlaylistDetailFullResponse: Codable {
    let playlist: APIPlaylist?
    let code: Int?
}

// MARK: - Personalized New Song

struct PersonalizedNewSongResponse: Codable {
    let result: [NewSongWrapper]?
    let code: Int?
}

struct NewSongWrapper: Codable, Identifiable {
    let id: Int
    let name: String?
    let song: APISong?
    let picUrl: String?

    var asAPISong: APISong? {
        guard let s = song else { return nil }
        if s.coverUrl == nil || s.coverUrl?.isEmpty == true, let pic = picUrl {
            let safePic = pic.hasPrefix("http://") ? pic.replacingOccurrences(of: "http://", with: "https://") : pic
            return APISong(
                id: s.id,
                name: s.name,
                ar: s.ar,
                al: APIAlbumBrief(id: s.al?.id, name: s.al?.name, picUrl: safePic),
                dt: s.dt
            )
        }
        return s
    }
}

// MARK: - Banner

struct BannerResponse: Codable {
    let banners: [APIBanner]?
    let code: Int?
}

struct APIBanner: Codable, Identifiable {
    let imageUrl: String
    let bigImageUrl: String?
    let targetId: Int?
    let targetType: Int?
    let typeTitle: String?
    let url: String?
    var id: String { "\(targetType ?? 0)_\(targetId ?? 0)_\(imageUrl)" }
}

// MARK: - Artist

struct TopArtistsResponse: Codable {
    let artists: [APIArtistDetail]?
    let code: Int?
}

struct APIArtistDetail: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let picUrl: String?
    let img1v1Url: String?
    let albumSize: Int?
    let musicSize: Int?
    var cover: String? = nil
    var avatar: String? = nil

    var avatarUrl: String? {
        SafeURLHelper.chooseImage(from: [img1v1Url, picUrl, avatar, cover])
    }

    var coverUrl: String? {
        SafeURLHelper.chooseImage(from: [picUrl, cover, img1v1Url, avatar])
    }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: APIArtistDetail, rhs: APIArtistDetail) -> Bool { lhs.id == rhs.id }
}

// MARK: - Album

struct APIAlbumDetail: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let picUrl: String?
    let artist: APIArtistBrief?
    let size: Int?
    let description: String?
    let publishTime: Int?
    let company: String?

    var coverUrl: String? {
        picUrl?.httpsURL
    }

    private static let yearFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy"
        return f
    }()

    private static let publishDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy年M月d日"
        return f
    }()

    var publishYear: String {
        guard let time = publishTime, time > 0 else { return "" }
        let date = Date(timeIntervalSince1970: TimeInterval(time) / 1000.0)
        return Self.yearFormatter.string(from: date)
    }

    var publishDateText: String {
        guard let time = publishTime, time > 0 else { return "" }
        let date = Date(timeIntervalSince1970: TimeInterval(time) / 1000.0)
        return Self.publishDateFormatter.string(from: date)
    }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: APIAlbumDetail, rhs: APIAlbumDetail) -> Bool { lhs.id == rhs.id }
}

struct NewAlbumsResponse: Codable {
    let albums: [APIAlbumDetail]?
    let code: Int?
}

struct AlbumDetailResponse: Codable {
    let album: APIAlbumDetail?
    let songs: [APISong]?
    let code: Int?
}

// MARK: - Artist Detail & Albums

struct ArtistDetailResponse: Codable {
    let artist: APIArtistDetail?
    let hotSongs: [APISong]?
    let code: Int?
}

struct ArtistAlbumResponse: Codable {
    let hotAlbums: [APIAlbumDetail]?
    let code: Int?
}

// MARK: - Daily Recommend Songs

struct DailySongsResponse: Codable {
    let data: DailySongsData?
    let code: Int?
}

struct DailySongsData: Codable {
    let dailySongs: [APISong]?
}

// MARK: - Like

struct LikeListResponse: Codable {
    let ids: [Int]?
    let code: Int?
}

struct BaseAPIResponse: Codable {
    let code: Int?
    let message: String?
}

// MARK: - Hot Search

struct HotSearchResponse: Codable {
    let data: [HotSearchItem]?
    let code: Int?
}

struct HotSearchItem: Codable, Identifiable {
    let searchWord: String
    let score: Int?
    let content: String?
    var id: String { searchWord }
}

// MARK: - Toplist

struct ToplistResponse: Codable {
    let list: [APIPlaylist]?
    let code: Int?
}

// MARK: - User Playlist

struct UserPlaylistResponse: Codable {
    let playlist: [APIPlaylist]?
    let code: Int?
}


// MARK: - QR Login

struct QRKeyResponse: Codable {
    let data: QRKeyData?
    let code: Int?
}

struct QRKeyData: Codable {
    let unikey: String?
}

struct QRCreateResponse: Codable {
    let data: QRCreateData?
    let code: Int?
}

struct QRCreateData: Codable {
    let qrurl: String?
    let qrimg: String?
}

struct QRCheckResponse: Codable {
    let code: Int?
    let message: String?
    let cookie: String?
}

// MARK: - Login Status

struct LoginStatusResponse: Codable {
    let data: LoginStatusData?
}

struct LoginStatusData: Codable {
    let profile: UserProfile?
}

struct UserProfile: Codable {
    let userId: Int?
    let nickname: String?
    let avatarUrl: String?

    var displayAvatar: String? {
        avatarUrl?.httpsURL
    }
}

// MARK: - DJ Radio (广播 / 电台 / 播客)

struct APIDJRadio: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let picUrl: String?
    let rcmdtext: String?
    let rcmdText: String?
    let category: String?
    let subCount: Int?
    let programCount: Int?
    let desc: String?
    let dj: APIDJHost?

    var displayDesc: String {
        desc ?? rcmdtext ?? rcmdText ?? ""
    }

    var displaySubCount: String {
        guard let count = subCount, count > 0 else { return "" }
        if count >= 10000 {
            return String(format: "%.1f万订阅", Double(count) / 10000.0)
        }
        return "\(count) 订阅"
    }

    var displayCover: String? {
        picUrl?.httpsURL
    }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: APIDJRadio, rhs: APIDJRadio) -> Bool { lhs.id == rhs.id }
}

struct APIDJHost: Codable, Identifiable, Hashable {
    let userId: Int?
    let nickname: String?
    let avatarUrl: String?
    var id: Int { userId ?? 0 }

    var displayAvatar: String? {
        avatarUrl?.httpsURL
    }
}

struct APIDJBanner: Codable, Identifiable, Hashable {
    let targetId: Int?
    let targetType: Int?
    let pic: String?
    let url: String?
    let typeTitle: String?
    var id: String { "\(targetId ?? 0)_\(pic ?? "")" }

    var displayPic: String? {
        pic?.httpsURL
    }
}

struct APIDJCategory: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let pic56x56Url: String?
}

struct APIDJToplistItem: Codable, Identifiable, Hashable {
    let program: APIDJProgram
    let rank: Int?
    var id: Int { program.id }
}

struct APIDJProgram: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let coverUrl: String?
    let listenerCount: Int?
    let duration: Int?
    let createTime: Int64?
    let mainSong: APIDJMainSong?
    let radio: APIDJRadioBrief?
    let dj: APIDJHost?

    var displayCover: String? {
        (coverUrl ?? radio?.picUrl)?.httpsURL
    }

    var asAPISong: APISong? {
        guard let song = mainSong else { return nil }
        let hostName = dj?.nickname ?? radio?.name ?? song.artists?.first?.name ?? "电台主播"
        let radioName = radio?.name ?? name
        let pic = (coverUrl ?? radio?.picUrl ?? song.album?.picUrl)?.httpsURL
        return APISong(
            id: song.id,
            name: name,
            ar: [APIArtistBrief(id: 0, name: hostName, picUrl: dj?.avatarUrl?.httpsURL)],
            al: APIAlbumBrief(id: radio?.id ?? 0, name: radioName, picUrl: pic),
            dt: duration ?? song.duration ?? 0
        )
    }

    var displayListenerCount: String {
        guard let count = listenerCount, count > 0 else { return "" }
        if count >= 10000 {
            return String(format: "%.1f万人收听", Double(count) / 10000.0)
        }
        return "\(count)次收听"
    }

    var durationText: String {
        let s = (duration ?? 0) / 1000
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: APIDJProgram, rhs: APIDJProgram) -> Bool { lhs.id == rhs.id }
}

struct APIDJMainSong: Codable, Identifiable, Hashable {
    let id: Int
    let name: String?
    let duration: Int?
    let artists: [APIArtistBrief]?
    let album: APIAlbumBrief?
}

struct APIDJRadioBrief: Codable, Identifiable, Hashable {
    let id: Int?
    let name: String?
    let picUrl: String?

    var displayCover: String? {
        picUrl?.httpsURL
    }
}

struct DJBannerResponse: Codable {
    let data: [APIDJBanner]?
    let code: Int?
}

struct DJRecommendResponse: Codable {
    let djRadios: [APIDJRadio]?
    let code: Int?
}

struct DJProgramToplistResponse: Codable {
    let toplist: [APIDJToplistItem]?
    let code: Int?
}

struct DJCategoryResponse: Codable {
    let categories: [APIDJCategory]?
    let code: Int?
}

struct DJDetailResponse: Codable {
    let data: APIDJRadio?
    let code: Int?
}

struct DJProgramResponse: Codable {
    let programs: [APIDJProgram]?
    let count: Int?
    let code: Int?
}

struct DJProgramDetailResponse: Codable {
    let program: APIDJProgram?
    let code: Int?
}
