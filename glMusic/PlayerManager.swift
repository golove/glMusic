//
//  PlayerManager.swift
//  glMusic
//
//  Created by go love on 10/23/26.
//

import SwiftUI
import AVFoundation

@Observable
final class PlayerManager {

    // MARK: - Playback State

    var currentSong: APISong?
    var isPlaying: Bool = false
    var currentTime: TimeInterval = 0
    var duration: TimeInterval = 0
    var volume: Double = 0.7 {
        didSet {
            player.volume = Float(volume)
            UserDefaults.standard.set(volume, forKey: "player_volume")
        }
    }
    var isShuffled: Bool = false
    var repeatMode: RepeatMode = .off
    var isLoading: Bool = false

    // MARK: - UI States

    var isShowingLyrics: Bool = false
    var isShowingQueue: Bool = false

    // MARK: - Lyrics

    var lyrics: [LyricLine] = []
    var currentLyricIndex: Int = 0
    var isLoadingLyrics: Bool = false

    // MARK: - Likes

    var likedSongIds: Set<Int> = []

    // MARK: - Playlist

    var playlist: [APISong] = []
    var currentIndex: Int = -1

    // MARK: - AVPlayer

    private var player = AVPlayer()
    private var timeObserver: Any?
    private var itemStatusObserver: NSKeyValueObservation?

    // MARK: - Computed

    var progress: Double {
        get { duration > 0 ? currentTime / duration : 0 }
        set {
            let target = newValue * duration
            currentTime = target
            player.seek(to: CMTime(seconds: target, preferredTimescale: 600))
        }
    }

    var currentTimeText: String { formatTime(currentTime) }
    var remainingTimeText: String { "-" + formatTime(max(0, duration - currentTime)) }

    // MARK: - Init

    init() {
        let savedVol = UserDefaults.standard.double(forKey: "player_volume")
        if savedVol > 0 {
            volume = savedVol
        }
        player.volume = Float(volume)
        setupTimeObserver()
        setupEndObserver()
    }

    // MARK: - Play Song

    func play(_ song: APISong) {
        currentSong = song
        duration = Double(song.durationMs) / 1000.0
        currentTime = 0
        currentLyricIndex = 0
        isLoading = true

        // Update playlist
        if let idx = playlist.firstIndex(where: { $0.id == song.id }) {
            currentIndex = idx
        } else {
            playlist.append(song)
            currentIndex = playlist.count - 1
        }

        // Save last played
        UserDefaults.standard.set(song.id, forKey: "last_played_song_id")

        Task {
            async let playTask: Void = loadAndPlay(songId: song.id)
            async let lyricTask: Void = loadLyrics(for: song.id)
            _ = await (playTask, lyricTask)
        }
    }

    func playAll(_ songs: [APISong], from index: Int = 0) {
        playlist = songs
        guard index >= 0 && index < songs.count else { return }
        currentIndex = index
        play(songs[index])
    }

    func seek(to time: TimeInterval) {
        currentTime = min(max(time, 0), duration)
        player.seek(to: CMTime(seconds: currentTime, preferredTimescale: 600))
    }

    private func loadAndPlay(songId: Int) async {
        // 1. 优先检查本地是否已下载：支持完全离线播放、0 秒缓冲与无损本地解码
        if let localURL = DownloadManager.shared.localAudioURL(for: songId) {
            print("💾 播放本地已下载音频: \(currentSong?.name ?? "") → \(localURL.lastPathComponent)")
            guard currentSong?.id == songId else { return }
            let item = AVPlayerItem(url: localURL)
            itemStatusObserver = item.observe(\.status, options: [.new]) { [weak self] observedItem, _ in
                guard let self = self else { return }
                if observedItem.status == .failed {
                    let errMsg = observedItem.error?.localizedDescription ?? "未知错误"
                    print("❌ 本地音频播放失败: \(errMsg)")
                    self.isPlaying = false
                    self.isLoading = false
                }
            }
            player.replaceCurrentItem(with: item)
            player.play()
            isPlaying = true
            isLoading = false
            return
        }

        // 2. 本地未下载，走网络流媒体加载
        do {
            // 尝试 standard → exhigh 两种品质
            var urlStr = try await NetworkManager.shared.songURL(id: songId, level: "standard")
            if urlStr == nil || urlStr?.isEmpty == true {
                urlStr = try await NetworkManager.shared.songURL(id: songId, level: "exhigh")
            }

            // 灰色歌曲兜底：使用 UnblockNeteaseMusic 匹配
            if urlStr == nil || urlStr?.isEmpty == true {
                print("🔓 尝试 songURLMatch 解锁灰色歌曲 \(songId)...")
                urlStr = try await NetworkManager.shared.songURLMatch(id: songId)
            }

            guard let finalUrl = urlStr, !finalUrl.isEmpty,
                  let url = URL(string: finalUrl) else {
                print("⚠️ 歌曲 \(songId) 无可用 URL，自动跳过")
                isLoading = false
                // 自动跳下一首
                if playlist.count > 1 {
                    next()
                } else {
                    isPlaying = false
                }
                return
            }

            // 确保切歌时旧的网络请求不会覆盖当前最新的歌曲
            guard currentSong?.id == songId else { return }

            print("▶️ 播放: \(currentSong?.name ?? "") → \(finalUrl.prefix(80))...")
            let item = AVPlayerItem(url: url)
            itemStatusObserver = item.observe(\.status, options: [.new]) { [weak self] observedItem, _ in
                guard let self = self else { return }
                if observedItem.status == .failed {
                    let errMsg = observedItem.error?.localizedDescription ?? "未知错误"
                    print("❌ 音频加载失败: \(errMsg)")
                    self.isPlaying = false
                    self.isLoading = false
                }
            }
            player.replaceCurrentItem(with: item)
            player.play()
            isPlaying = true
            isLoading = false
        } catch {
            print("❌ 播放失败: \(error)")
            isLoading = false
        }
    }

    // MARK: - Lyrics Loading & Parsing

    func loadLyrics(for songId: Int) async {
        isLoadingLyrics = true
        lyrics = []
        currentLyricIndex = 0

        // 优先读取本地已缓存或下载的歌词文本 (支持双语翻译)
        if let localLrc = DownloadManager.shared.localLyrics(for: songId) {
            let localTrans = DownloadManager.shared.localTranslation(for: songId)
            let parsed = Self.parseLRC(lrc: localLrc, translation: localTrans)
            if !parsed.isEmpty {
                self.lyrics = parsed
                isLoadingLyrics = false
                return
            }
        }

        do {
            let resp = try await NetworkManager.shared.lyrics(id: songId)
            let parsed = Self.parseLRC(lrc: resp.lrc?.lyric ?? "", translation: resp.tlyric?.lyric)
            self.lyrics = parsed
        } catch {
            print("加载歌词失败: \(error)")
        }
        isLoadingLyrics = false
    }

    static func parseLRC(lrc: String, translation: String? = nil) -> [LyricLine] {
        var transMap: [Int: String] = [:]
        if let trans = translation {
            for line in trans.components(separatedBy: .newlines) {
                if let (time, text) = parseLine(line), !text.trimmingCharacters(in: .whitespaces).isEmpty {
                    let key = Int(time * 10)
                    transMap[key] = text.trimmingCharacters(in: .whitespaces)
                }
            }
        }

        var result: [LyricLine] = []
        for line in lrc.components(separatedBy: .newlines) {
            if let (time, text) = parseLine(line) {
                let trimmed = text.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty {
                    let key = Int(time * 10)
                    var matchedTrans: String? = transMap[key]
                    if matchedTrans == nil {
                        for offset in [-2, -1, 1, 2] {
                            if let t = transMap[key + offset] {
                                matchedTrans = t
                                break
                            }
                        }
                    }
                    result.append(LyricLine(time: time, text: trimmed, translation: matchedTrans))
                }
            }
        }
        return result.sorted { $0.time < $1.time }
    }

    private static func parseLine(_ line: String) -> (TimeInterval, String)? {
        guard line.hasPrefix("["), let closingBracket = line.firstIndex(of: "]") else { return nil }
        let timeStr = String(line[line.index(after: line.startIndex)..<closingBracket])
        let text = String(line[line.index(after: closingBracket)...])

        let parts = timeStr.split(separator: ":")
        guard parts.count == 2,
              let minutes = Double(parts[0]),
              let seconds = Double(parts[1]) else { return nil }
        return (minutes * 60.0 + seconds, text)
    }

    // MARK: - Likes

    func isLiked(_ songId: Int) -> Bool {
        likedSongIds.contains(songId)
    }

    func toggleLike(for song: APISong) {
        let currentlyLiked = isLiked(song.id)
        if currentlyLiked {
            likedSongIds.remove(song.id)
        } else {
            likedSongIds.insert(song.id)
        }
        Task {
            do {
                _ = try await NetworkManager.shared.likeSong(id: song.id, like: !currentlyLiked)
            } catch {
                print("Like error: \(error)")
                if currentlyLiked {
                    self.likedSongIds.insert(song.id)
                } else {
                    self.likedSongIds.remove(song.id)
                }
            }
        }
    }

    func loadLikedSongs(uid: Int) async {
        do {
            let ids = try await NetworkManager.shared.likeList(uid: uid)
            likedSongIds = Set(ids)
        } catch {
            print("加载喜欢音乐失败: \(error)")
        }
    }

    // MARK: - Queue Management

    func removeFromPlaylist(song: APISong) {
        if let idx = playlist.firstIndex(where: { $0.id == song.id }) {
            playlist.remove(at: idx)
            if let cur = currentSong, let newIdx = playlist.firstIndex(where: { $0.id == cur.id }) {
                currentIndex = newIdx
            }
        }
    }

    func clearPlaylist() {
        if let cur = currentSong {
            playlist = [cur]
            currentIndex = 0
        } else {
            playlist = []
            currentIndex = -1
        }
    }

    func addToPlaylist(_ song: APISong) {
        if !playlist.contains(where: { $0.id == song.id }) {
            playlist.append(song)
        }
    }

    func playNext(_ song: APISong) {
        playlist.removeAll(where: { $0.id == song.id })
        let insertIndex = min(currentIndex + 1, playlist.count)
        playlist.insert(song, at: insertIndex)
    }

    // MARK: - Controls

    func togglePlay() {
        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            // 1. 如果播放项不存在或处于失败状态，但有当前歌曲，则重新发起网络请求并播放
            if player.currentItem == nil || player.currentItem?.status == .failed {
                if let song = currentSong {
                    play(song)
                    return
                }
            }

            // 2. 检查是否在末尾或接近末尾（播放完毕或拖动到了末尾）
            let atEnd: Bool = {
                if duration > 0 && currentTime >= duration - 0.5 {
                    return true
                }
                if let item = player.currentItem {
                    let cur = item.currentTime().seconds
                    let dur = item.duration.seconds
                    if dur.isFinite && dur > 0 && cur >= dur - 0.5 {
                        return true
                    }
                }
                return false
            }()

            if atEnd {
                currentTime = 0
                currentLyricIndex = 0
                player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] finished in
                    guard let self else { return }
                    if !finished || self.player.currentItem?.status == .failed {
                        if let song = self.currentSong {
                            self.play(song)
                            return
                        }
                    }
                    self.player.play()
                    self.isPlaying = true
                }
                isPlaying = true
                return
            }

            player.play()
            isPlaying = true
        }
    }

    func next() {
        guard !playlist.isEmpty else { return }
        if isShuffled {
            currentIndex = Int.random(in: 0..<playlist.count)
        } else {
            currentIndex = (currentIndex + 1) % playlist.count
        }
        play(playlist[currentIndex])
    }

    func previous() {
        if currentTime > 3 {
            player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
            currentTime = 0
            currentLyricIndex = 0
            return
        }
        guard !playlist.isEmpty else { return }
        currentIndex = (currentIndex - 1 + playlist.count) % playlist.count
        play(playlist[currentIndex])
    }

    func toggleShuffle() { isShuffled.toggle() }

    func cycleRepeat() {
        switch repeatMode {
        case .off:  repeatMode = .all
        case .all:  repeatMode = .one
        case .one:  repeatMode = .off
        }
    }

    // MARK: - Observers

    private func setupTimeObserver() {
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.3, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            guard let self else { return }
            let t = time.seconds
            if t.isFinite {
                self.currentTime = t
                if !self.lyrics.isEmpty {
                    if let idx = self.lyrics.lastIndex(where: { $0.time <= t }) {
                        if self.currentLyricIndex != idx {
                            self.currentLyricIndex = idx
                        }
                    } else {
                        self.currentLyricIndex = 0
                    }
                }
            }
        }
    }

    private func setupEndObserver() {
        NotificationCenter.default.addObserver(
            forName: AVPlayerItem.didPlayToEndTimeNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }

            // 仅响应当前正在播放的 item 的结束通知
            if let item = notification.object as? AVPlayerItem,
               let currentItem = self.player.currentItem,
               item != currentItem {
                return
            }

            switch self.repeatMode {
            case .one:
                self.currentTime = 0
                self.currentLyricIndex = 0
                self.player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
                    self?.player.play()
                    self?.isPlaying = true
                }
            case .all:
                self.next()
            case .off:
                if self.currentIndex < self.playlist.count - 1 {
                    self.next()
                } else {
                    self.isPlaying = false
                    self.currentTime = 0
                    self.currentLyricIndex = 0
                    self.player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
                }
            }
        }
    }

    // MARK: - Helpers

    enum RepeatMode {
        case off, all, one
        var systemImage: String {
            switch self {
            case .off:  return "repeat"
            case .all:  return "repeat"
            case .one:  return "repeat.1"
            }
        }
        var isActive: Bool { self != .off }
    }

    private func formatTime(_ t: TimeInterval) -> String {
        let m = Int(t) / 60
        let s = Int(t) % 60
        return String(format: "%d:%02d", m, s)
    }
}
