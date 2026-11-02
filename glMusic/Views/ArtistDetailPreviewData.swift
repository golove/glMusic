//
//  ArtistDetailPreviewData.swift
//  glMusic
//
//  Created by go love on 10/31/26.
//


import Foundation

enum ArtistDetailPreviewData {

    // MARK: - 模拟艺人

    static let artist = APIArtistDetail(
        id: 10001,
        name: "王菲",
        picUrl: "https://picsum.photos/300/300?random=11",
        img1v1Url: "https://picsum.photos/300/300?random=11",
        albumSize: 12,
        musicSize: 86
    )

    // MARK: - 模拟热门歌曲

    private static let artistBrief = APIArtistBrief(
        id: 10001,
        name: "王菲",
        picUrl: "https://picsum.photos/300/300?random=11"
    )

    private static let albumsForSongs: [APIAlbumBrief] = [
        APIAlbumBrief(
            id: 501,
            name: "寓言",
            picUrl: "https://picsum.photos/300/300?random=21"
        ),
        APIAlbumBrief(
            id: 502,
            name: "天空",
            picUrl: "https://picsum.photos/300/300?random=22"
        ),
        APIAlbumBrief(
            id: 503,
            name: "唱游",
            picUrl: "https://picsum.photos/300/300?random=23"
        ),
        APIAlbumBrief(
            id: 504,
            name: "只爱陌生人",
            picUrl: "https://picsum.photos/300/300?random=24"
        )
    ]

    static let hotSongs: [APISong] = [
        APISong(id: 1001, name: "红豆", ar: [artistBrief], al: albumsForSongs[0], dt: 258000),
        APISong(id: 1002, name: "匆匆那年", ar: [artistBrief], al: albumsForSongs[1], dt: 246000),
        APISong(id: 1003, name: "传奇", ar: [artistBrief], al: albumsForSongs[2], dt: 273000),
        APISong(id: 1004, name: "暧昧", ar: [artistBrief], al: albumsForSongs[3], dt: 259000),
        APISong(id: 1005, name: "流年", ar: [artistBrief], al: albumsForSongs[1], dt: 294000),
        APISong(id: 1006, name: "人间", ar: [artistBrief], al: albumsForSongs[2], dt: 241000),
        APISong(id: 1007, name: "笑忘书", ar: [artistBrief], al: albumsForSongs[3], dt: 229000),
        APISong(id: 1008, name: "梦中人", ar: [artistBrief], al: albumsForSongs[0], dt: 234000)
    ]

    // MARK: - 模拟专辑

    static let albums: [APIAlbumDetail] = [
        APIAlbumDetail(
            id: 501,
            name: "寓言",
            picUrl: "https://picsum.photos/300/300?random=21",
            artist: artistBrief,
            size: 10,
            description: "模拟专辑，用于测试艺人详情页布局。",
            publishTime: 962323200000,
            company: "模拟唱片公司"
        ),
        APIAlbumDetail(
            id: 502,
            name: "天空",
            picUrl: "https://picsum.photos/300/300?random=22",
            artist: artistBrief,
            size: 11,
            description: "模拟专辑，用于测试专辑卡片。",
            publishTime: 820454400000,
            company: "模拟唱片公司"
        ),
        APIAlbumDetail(
            id: 503,
            name: "唱游",
            picUrl: "https://picsum.photos/300/300?random=23",
            artist: artistBrief,
            size: 10,
            description: "模拟专辑，用于测试网格排列。",
            publishTime: 900000000000,
            company: "模拟唱片公司"
        ),
        APIAlbumDetail(
            id: 504,
            name: "只爱陌生人",
            picUrl: "https://picsum.photos/300/300?random=24",
            artist: artistBrief,
            size: 10,
            description: "模拟专辑，用于测试页面滚动。",
            publishTime: 936000000000,
            company: "模拟唱片公司"
        ),
        APIAlbumDetail(
            id: 505,
            name: "将爱",
            picUrl: "https://picsum.photos/300/300?random=25",
            artist: artistBrief,
            size: 12,
            description: "模拟专辑。",
            publishTime: 1000000000000,
            company: "模拟唱片公司"
        ),
        APIAlbumDetail(
            id: 506,
            name: "浮躁",
            picUrl: "https://picsum.photos/300/300?random=26",
            artist: artistBrief,
            size: 10,
            description: "模拟专辑。",
            publishTime: 830000000000,
            company: "模拟唱片公司"
        )
    ]
}
