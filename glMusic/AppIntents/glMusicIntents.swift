//
//  glMusicIntents.swift
//  glMusic
//
//  Created by go love on 11/14/26.
//

import AppIntents
import SwiftUI

// MARK: - 1. 播放音乐 Intent

struct PlayMusicIntent: AppIntent {
    static var title: LocalizedStringResource = "播放音乐"
    static var description = IntentDescription("在 glMusic 中开始或恢复播放音乐")
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let player = PlayerManager.shared else {
            return .result(dialog: "glMusic 尚未运行，请先启动应用")
        }
        player.playOrResume()
        if let current = player.currentSong {
            let name = current.name
            let artist = current.displayArtist
            return .result(dialog: "正在播放：\(name) - \(artist)")
        } else {
            return .result(dialog: "已开始播放音乐")
        }
    }
}

// MARK: - 2. 暂停音乐 Intent

struct PauseMusicIntent: AppIntent {
    static var title: LocalizedStringResource = "暂停音乐"
    static var description = IntentDescription("暂停 glMusic 当前播放")
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let player = PlayerManager.shared else {
            return .result(dialog: "glMusic 尚未运行")
        }
        player.pause()
        return .result(dialog: "已暂停播放")
    }
}

// MARK: - 3. 播放/暂停切换 Intent

struct TogglePlayPauseIntent: AppIntent {
    static var title: LocalizedStringResource = "播放或暂停"
    static var description = IntentDescription("切换 glMusic 的播放或暂停状态")
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let player = PlayerManager.shared else {
            return .result(dialog: "glMusic 尚未运行")
        }
        player.togglePlay()
        if player.isPlaying {
            return .result(dialog: "正在播放")
        } else {
            return .result(dialog: "已暂停")
        }
    }
}

// MARK: - 4. 下一首 Intent

struct NextTrackIntent: AppIntent {
    static var title: LocalizedStringResource = "下一首"
    static var description = IntentDescription("跳至下一首歌曲")
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let player = PlayerManager.shared else {
            return .result(dialog: "glMusic 尚未运行")
        }
        player.next()
        if let song = player.currentSong {
            let name = song.name
            return .result(dialog: "已切换到下一首：\(name)")
        }
        return .result(dialog: "已切换下一首")
    }
}

// MARK: - 5. 上一首 Intent

struct PreviousTrackIntent: AppIntent {
    static var title: LocalizedStringResource = "上一首"
    static var description = IntentDescription("返回上一首歌曲")
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let player = PlayerManager.shared else {
            return .result(dialog: "glMusic 尚未运行")
        }
        player.previous()
        if let song = player.currentSong {
            let name = song.name
            return .result(dialog: "已返回上一首：\(name)")
        }
        return .result(dialog: "已切换上一首")
    }
}

// MARK: - 6. 播放每日推荐 Intent

struct PlayDailyRecommendIntent: AppIntent {
    static var title: LocalizedStringResource = "播放每日推荐"
    static var description = IntentDescription("在 glMusic 中自动播放今日推荐歌单")
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let player = PlayerManager.shared else {
            return .result(dialog: "请先启动 glMusic")
        }
        do {
            let songs = try await NetworkManager.shared.dailyRecommendSongs()
            if !songs.isEmpty {
                player.playAll(songs)
                let count = songs.count
                return .result(dialog: "已为您开始播放今日每日推荐 (\(count) 首歌曲)")
            } else {
                return .result(dialog: "未能获取到今日推荐歌曲，请检查网络或登录状态")
            }
        } catch {
            let msg = error.localizedDescription
            return .result(dialog: "获取每日推荐失败：\(msg)")
        }
    }
}

// MARK: - 7. 播放我喜欢的音乐 Intent

struct PlayLikedMusicIntent: AppIntent {
    static var title: LocalizedStringResource = "播放我喜欢的音乐"
    static var description = IntentDescription("在 glMusic 中播放我喜欢的音乐歌单")
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let player = PlayerManager.shared else {
            return .result(dialog: "请先启动 glMusic")
        }
        do {
            guard let profile = try await NetworkManager.shared.loginStatus(),
                  let uid = profile.userId else {
                return .result(dialog: "请先在 glMusic 中登录网易云音乐账号")
            }
            let playlists = try await NetworkManager.shared.userPlaylists(uid: uid, limit: 1)
            guard let firstPl = playlists.first else {
                return .result(dialog: "未找到您的歌单")
            }
            let songs = try await NetworkManager.shared.playlistTracks(id: firstPl.id, limit: 100)
            if !songs.isEmpty {
                player.playAll(songs)
                let count = songs.count
                return .result(dialog: "已为您开始播放我喜欢的音乐 (\(count) 首)")
            } else {
                return .result(dialog: "我喜欢的音乐歌单为空")
            }
        } catch {
            let msg = error.localizedDescription
            return .result(dialog: "播放失败：\(msg)")
        }
    }
}

// MARK: - 8. macOS Shortcuts & Siri 聚焦搜索捷径提供商 (AppShortcutsProvider)

struct glMusicShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: PlayMusicIntent(),
            phrases: [
                "在 \(.applicationName) 播放音乐",
                "播放 \(.applicationName)",
                "继续播放 \(.applicationName)"
            ],
            shortTitle: "播放音乐",
            systemImageName: "play.fill"
        )
        AppShortcut(
            intent: PauseMusicIntent(),
            phrases: [
                "在 \(.applicationName) 暂停音乐",
                "暂停 \(.applicationName)"
            ],
            shortTitle: "暂停音乐",
            systemImageName: "pause.fill"
        )
        AppShortcut(
            intent: TogglePlayPauseIntent(),
            phrases: [
                "在 \(.applicationName) 切换播放",
                "切换 \(.applicationName) 播放状态"
            ],
            shortTitle: "播放或暂停",
            systemImageName: "playpause.fill"
        )
        AppShortcut(
            intent: NextTrackIntent(),
            phrases: [
                "\(.applicationName) 下一首",
                "在 \(.applicationName) 播放下一首",
                "\(.applicationName) 切歌"
            ],
            shortTitle: "下一首",
            systemImageName: "forward.fill"
        )
        AppShortcut(
            intent: PreviousTrackIntent(),
            phrases: [
                "\(.applicationName) 上一首",
                "在 \(.applicationName) 播放上一首"
            ],
            shortTitle: "上一首",
            systemImageName: "backward.fill"
        )
        AppShortcut(
            intent: PlayDailyRecommendIntent(),
            phrases: [
                "在 \(.applicationName) 播放每日推荐",
                "播放 \(.applicationName) 每日推荐",
                "听 \(.applicationName) 每日推荐"
            ],
            shortTitle: "播放每日推荐",
            systemImageName: "sparkles"
        )
        AppShortcut(
            intent: PlayLikedMusicIntent(),
            phrases: [
                "在 \(.applicationName) 播放我喜欢的音乐",
                "播放 \(.applicationName) 我喜欢的歌",
                "播放 \(.applicationName) 喜欢的音乐"
            ],
            shortTitle: "播放我喜欢的音乐",
            systemImageName: "heart.fill"
        )
    }
}
