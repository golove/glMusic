//
//  InfiniteRoamingAndFMTests.swift
//  glMusicTests
//
//  Created by go love on 11/14/26.
//

import XCTest
@testable import glMusic

final class InfiniteRoamingAndFMTests: XCTestCase {

    func testPersonalFmResponseDecoding() throws {
        let json = """
        {
            "code": 200,
            "data": [
                {
                    "name": "海阔天空",
                    "id": 347230,
                    "duration": 326000,
                    "artists": [
                        { "name": "Beyond", "id": 11127 }
                    ],
                    "album": {
                        "name": "海阔天空",
                        "id": 34220,
                        "picUrl": "http://p1.music.126.net/xyz/cover.jpg"
                    }
                }
            ],
            "popAdjust": true
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(PersonalFmResponse.self, from: json)
        XCTAssertEqual(response.code, 200)
        XCTAssertEqual(response.data?.count, 1)

        let song = try XCTUnwrap(response.data?.first)
        XCTAssertEqual(song.id, 347230)
        XCTAssertEqual(song.name, "海阔天空")
        XCTAssertEqual(song.displayArtist, "Beyond")
        XCTAssertEqual(song.displayAlbum, "海阔天空")
        XCTAssertEqual(song.coverUrl, "https://p1.music.126.net/xyz/cover.jpg")
    }

    func testSimiSongResponseDecoding() throws {
        let json = """
        {
            "code": 200,
            "songs": [
                {
                    "id": 1001,
                    "name": "光辉岁月",
                    "artists": [{ "name": "Beyond", "id": 11127 }],
                    "duration": 300000
                },
                {
                    "id": 1002,
                    "name": "真的爱你",
                    "artists": [{ "name": "Beyond", "id": 11127 }],
                    "duration": 280000
                }
            ]
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(SimiSongResponse.self, from: json)
        XCTAssertEqual(response.code, 200)
        XCTAssertEqual(response.songs?.count, 2)
        XCTAssertEqual(response.songs?.first?.name, "光辉岁月")
    }

    func testIntelligenceListResponseDecoding() throws {
        let json = """
        {
            "code": 200,
            "message": "success",
            "data": [
                {
                    "id": 5001,
                    "recommended": true,
                    "songInfo": {
                        "id": 5001,
                        "name": "晴天",
                        "artists": [{ "name": "周杰伦", "id": 6452 }],
                        "duration": 269000
                    }
                }
            ]
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(IntelligenceListResponse.self, from: json)
        XCTAssertEqual(response.code, 200)
        XCTAssertEqual(response.data?.count, 1)

        let item = try XCTUnwrap(response.data?.first)
        let resolved = try XCTUnwrap(item.resolvedSong)
        XCTAssertEqual(resolved.id, 5001)
        XCTAssertEqual(resolved.name, "晴天")
        XCTAssertEqual(resolved.displayArtist, "周杰伦")
    }

    @MainActor
    func testPlayerManagerInfiniteRoamingToggle() {
        let player = PlayerManager()
        let initial = player.isInfiniteRoamingEnabled

        player.toggleInfiniteRoaming()
        XCTAssertEqual(player.isInfiniteRoamingEnabled, !initial)
        XCTAssertEqual(UserDefaults.standard.bool(forKey: "isInfiniteRoamingEnabled"), !initial)

        player.toggleInfiniteRoaming()
        XCTAssertEqual(player.isInfiniteRoamingEnabled, initial)
        XCTAssertEqual(UserDefaults.standard.bool(forKey: "isInfiniteRoamingEnabled"), initial)
    }

    @MainActor
    func testPlayerManagerPersonalFMMode() {
        let player = PlayerManager()
        player.isPersonalFM = true
        XCTAssertTrue(player.isPersonalFM)

        let testSong = APISong(
            id: 99999,
            name: "测试歌曲",
            ar: [APIArtistBrief(id: 1, name: "测试艺人", picUrl: nil)],
            al: APIAlbumBrief(id: 1, name: "测试专辑", picUrl: nil),
            dt: 180000
        )

        // 外部手动点播外部歌单应重置 FM 模式
        player.play(testSong)
        XCTAssertFalse(player.isPersonalFM)
    }

    @MainActor
    func testPlayerManagerFMTrashAdvancesTrack() {
        let player = PlayerManager()
        player.isPersonalFM = true

        let song1 = APISong(id: 101, name: "FM曲目1", ar: nil, al: nil, dt: 100000)
        let song2 = APISong(id: 102, name: "FM曲目2", ar: nil, al: nil, dt: 100000)
        player.playlist = [song1, song2]
        player.currentIndex = 0
        player.currentSong = song1

        // 触发垃圾桶
        player.trashCurrentFMSong()

        // 应当立即推进至下一曲
        XCTAssertEqual(player.currentIndex, 1)
        XCTAssertEqual(player.currentSong?.id, 102)
    }
}
