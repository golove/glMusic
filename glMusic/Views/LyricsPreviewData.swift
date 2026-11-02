//
//  LyricsPreviewData.swift
//  glMusic
//
//  Created by go love on 10/29/26.
//


import SwiftUI

struct LyricsPreviewData {
    static func makePlayer() -> PlayerManager {
        let player = PlayerManager()

        player.currentSong = APISong(
            id: 123456,
            name: "如愿",
            ar: [
                APIArtistBrief(
                    id: 1,
                    name: "王菲",
                    picUrl: nil
                )
            ],
            al: nil,
            dt: 254_000
        )

       
        player.lyrics = [
            LyricLine(
                time: 48,
                text: "你是遥遥的路",
                translation: "You are the distant road"
            ),
            LyricLine(
                time: 53,
                text: "山野大雾里的灯",
                translation: "A light in the mountain mist"
            ),
            LyricLine(
                time: 58,
                text: "我是孩童啊，走在你的眼眸",
                translation: "I am a child, walking in your eyes"
            ),
            LyricLine(
                time: 63,
                text: "你是我生命中的光",
                translation: "You are the light of my life"
            ),
            LyricLine(
                time: 68,
                text: "让我愿意奔赴远方",
                translation: "You make me willing to travel far"
            )
        ]

        player.currentTime = 64
        player.duration = 254
        player.currentLyricIndex = 3

        return player

    }
}
