//
//  APIModels.swift
//  glMusic
//
//  Created by go love on 10/23/26.
//

import Foundation

// MARK: - Song

struct APISong: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let ar: [APIArtistBrief]?
    let al: APIAlbumBrief?
    let dt: Int?                   // duration in ms

    var displayArtist: String {
        (ar ?? []).compactMap(\.name).joined(separator: " / ")
    }
    var displayAlbum: String { al?.name ?? "" }
    var coverUrl: String? { al?.picUrl }
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
}

struct APIAlbumBrief: Codable, Identifiable, Hashable {
    let id: Int?
    let name: String?
    let picUrl: String?
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

    var displayCover: String? { coverImgUrl ?? picUrl }

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

    var publishYear: String {
        guard let time = publishTime, time > 0 else { return "" }
        let date = Date(timeIntervalSince1970: TimeInterval(time) / 1000.0)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter.string(from: date)
    }

    var publishDateText: String {
        guard let time = publishTime, time > 0 else { return "" }
        let date = Date(timeIntervalSince1970: TimeInterval(time) / 1000.0)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月d日"
        return formatter.string(from: date)
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

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: APIDJRadio, rhs: APIDJRadio) -> Bool { lhs.id == rhs.id }
}

struct APIDJHost: Codable, Identifiable, Hashable {
    let userId: Int?
    let nickname: String?
    let avatarUrl: String?
    var id: Int { userId ?? 0 }
}

struct APIDJBanner: Codable, Identifiable, Hashable {
    let targetId: Int?
    let targetType: Int?
    let pic: String?
    let url: String?
    let typeTitle: String?
    var id: String { "\(targetId ?? 0)_\(pic ?? "")" }
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

    var asAPISong: APISong? {
        guard let song = mainSong else { return nil }
        let hostName = dj?.nickname ?? radio?.name ?? song.artists?.first?.name ?? "电台主播"
        let radioName = radio?.name ?? name
        let pic = coverUrl ?? radio?.picUrl ?? song.album?.picUrl
        return APISong(
            id: song.id,
            name: name,
            ar: [APIArtistBrief(id: 0, name: hostName, picUrl: dj?.avatarUrl)],
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
