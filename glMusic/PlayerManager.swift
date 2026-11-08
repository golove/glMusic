//
//  PlayerManager.swift
//  glMusic
//
//  Created by go love on 10/23/26.
//

import SwiftUI
import AVFoundation
import MediaPlayer
import NeteaseCloudMusicAPI

@MainActor
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
    var soundQuality: SoundQualityType = .exhigh {
        didSet {
            UserDefaults.standard.set(soundQuality.rawValue, forKey: "player_sound_quality")
            if let song = currentSong, isPlaying {
                Task {
                    await reloadCurrentSongWithNewQuality()
                }
            }
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
            updateNowPlaying()
        }
    }

    var currentTimeText: String { formatTime(currentTime) }
    var remainingTimeText: String { "-" + formatTime(max(0, duration - currentTime)) }

    // MARK: - Init & Deinit

    init() {
        let savedVol = UserDefaults.standard.double(forKey: "player_volume")
        if savedVol > 0 {
            volume = savedVol
        }
        player.volume = Float(volume)

        if let savedQuality = UserDefaults.standard.string(forKey: "player_sound_quality"),
           let quality = SoundQualityType(rawValue: savedQuality) {
            self.soundQuality = quality
        }

        setupTimeObserver()
        setupEndObserver()
        setupRemoteCommands()
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

        // 自动记录到播放历史
        HistoryManager.shared.record(song: song)

        // Save last played
        UserDefaults.standard.set(song.id, forKey: "last_played_song_id")

        updateNowPlaying()
        fetchArtwork(for: song)

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
        updateNowPlaying()
    }

    private func loadAndPlay(songId: Int) async {
        // 1. 优先检查本地是否已下载：支持完全离线播放、0 秒缓冲与无损本地解码
        if let localURL = DownloadManager.shared.localAudioURL(for: songId) {
            print("💾 播放本地已下载音频: \(currentSong?.name ?? "") → \(localURL.lastPathComponent)")
            guard currentSong?.id == songId else { return }
            let item = AVPlayerItem(url: localURL)
            itemStatusObserver = item.observe(\.status, options: [.new]) { [weak self] observedItem, _ in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    if observedItem.status == .failed {
                        let errMsg = observedItem.error?.localizedDescription ?? "未知错误"
                        print("❌ 本地音频播放失败: \(errMsg)")
                        self.isPlaying = false
                        self.isLoading = false
                        self.updateNowPlaying()
                    }
                }
            }
            player.replaceCurrentItem(with: item)
            player.play()
            isPlaying = true
            isLoading = false
            updateNowPlaying()
            return
        }

        // 2. 本地未下载：若为本地导入歌曲 (songId < 0) 且本地文件不存在，直接提示错误，不请求网络
        if songId < 0 {
            print("❌ 本地导入音频文件不存在或已被移动 (songId: \(songId))")
            isPlaying = false
            isLoading = false
            updateNowPlaying()
            return
        }

        // 3. 走网络流媒体加载
        do {
            // 尝试当前设定的音质
            var urlStr = try await NetworkManager.shared.songURL(id: songId, level: soundQuality.rawValue)
            if urlStr == nil || urlStr?.isEmpty == true {
                urlStr = try await NetworkManager.shared.songURL(id: songId, level: "standard")
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
                    updateNowPlaying()
                }
                return
            }

            // 确保切歌时旧的网络请求不会覆盖当前最新的歌曲
            guard currentSong?.id == songId else { return }

            print("▶️ 播放: \(currentSong?.name ?? "") → \(finalUrl.prefix(80))...")
            let item = AVPlayerItem(url: url)
            itemStatusObserver = item.observe(\.status, options: [.new]) { [weak self] observedItem, _ in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    if observedItem.status == .failed {
                        let errMsg = observedItem.error?.localizedDescription ?? "未知错误"
                        print("❌ 音频加载失败: \(errMsg)")
                        self.isPlaying = false
                        self.isLoading = false
                        self.updateNowPlaying()
                    }
                }
            }
            player.replaceCurrentItem(with: item)
            player.play()
            isPlaying = true
            isLoading = false
            updateNowPlaying()
        } catch {
            print("❌ 播放失败: \(error)")
            isLoading = false
            updateNowPlaying()
        }
    }

    // MARK: - Lyrics Loading & Parsing

    func loadLyrics(for songId: Int) async {
        isLoadingLyrics = true
        lyrics = []
        currentLyricIndex = 0

        // 优先检查本地是否下载了离线歌词 / 本地伴生歌词
        if let localLrc = DownloadManager.shared.localLyrics(for: songId) {
            let localTrans = DownloadManager.shared.localTranslation(for: songId)
            let parsed = parseLyrics(yrc: nil, lrc: localLrc, translation: localTrans)
            lyrics = parsed
            isLoadingLyrics = false
            return
        }

        // 若为本地导入歌曲 (songId < 0) 且无本地伴生歌词，直接展示暂无本地歌词，不请求网络
        if songId < 0 {
            lyrics = [LyricLine(time: 0, text: "暂无本地歌词".localized)]
            isLoadingLyrics = false
            return
        }

        do {
            let resp = try await NetworkManager.shared.lyrics(id: songId)
            let parsed = parseLyrics(
                yrc: resp.yrc?.lyric,
                lrc: resp.lrc?.lyric,
                translation: resp.tlyric?.lyric
            )
            lyrics = parsed
        } catch {
            lyrics = [LyricLine(time: 0, text: "暂无歌词".localized)]
        }
        isLoadingLyrics = false
    }

    private func parseLyrics(yrc: String?, lrc: String?, translation: String?) -> [LyricLine] {
        // 1. 如果存在官方逐字歌词 (yrc)，优先进行毫秒级逐字解析
        if let yrc = yrc, !yrc.isEmpty {
            let yrcLines = parseYRC(yrc: yrc, translation: translation)
            if !yrcLines.isEmpty {
                return yrcLines
            }
        }

        // 2. 回退到标准行级歌词 (lrc)
        return parseLRC(lrc: lrc, translation: translation)
    }

    private func parseYRC(yrc: String, translation: String?) -> [LyricLine] {
        var lines: [LyricLine] = []
        let linePattern = /\[(\d+),(\d+)\](.*)/
        let wordPattern = /\((\d+),(\d+)(?:,\d+)?\)([^\(\)]*)/

        for rawLine in yrc.components(separatedBy: .newlines) {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            guard let lineMatch = trimmed.firstMatch(of: linePattern) else { continue }

            let lineStartMs = Double(lineMatch.1) ?? 0
            let lineDurMs = Double(lineMatch.2) ?? 0
            let lineBody = String(lineMatch.3)

            let lineStartTime = lineStartMs / 1000.0
            let lineDuration = lineDurMs / 1000.0

            var words: [LyricWord] = []
            var fullText = ""

            let wordMatches = lineBody.matches(of: wordPattern)
            for wm in wordMatches {
                let wStartMs = Double(wm.1) ?? 0
                let wDurMs = Double(wm.2) ?? 0
                let wText = String(wm.3)

                let wStartTime = wStartMs / 1000.0
                let wDuration = wDurMs / 1000.0

                if !wText.isEmpty {
                    words.append(LyricWord(time: wStartTime, duration: wDuration, text: wText))
                    fullText += wText
                }
            }

            let cleanText = fullText.trimmingCharacters(in: .whitespaces)
            if !cleanText.isEmpty {
                lines.append(LyricLine(
                    time: lineStartTime,
                    text: cleanText,
                    duration: lineDuration,
                    words: words
                ))
            }
        }

        guard !lines.isEmpty else { return [] }

        attachTranslation(to: &lines, translation: translation)

        return lines.sorted { $0.time < $1.time }
    }

    private func parseLRC(lrc: String?, translation: String?) -> [LyricLine] {
        guard let lrc = lrc, !lrc.isEmpty else { return [] }

        var lines: [LyricLine] = []
        let pattern = /\[(\d{2}):(\d{2})(?:\.(\d{2,3}))?\](.*)/

        for rawLine in lrc.components(separatedBy: .newlines) {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            if let match = trimmed.firstMatch(of: pattern) {
                let min = Double(match.1) ?? 0
                let sec = Double(match.2) ?? 0
                let msStr = match.3.map(String.init) ?? "0"
                let ms = (Double(msStr) ?? 0) / (msStr.count == 3 ? 1000.0 : 100.0)
                let time = min * 60 + sec + ms
                let text = String(match.4).trimmingCharacters(in: .whitespaces)

                if !text.isEmpty {
                    lines.append(LyricLine(time: time, text: text))
                }
            }
        }

        attachTranslation(to: &lines, translation: translation)

        var sortedLines = lines.sorted { $0.time < $1.time }

        // 计算每行歌词的持续时间：基于字数 × 320ms/字，并用下一行时间戳防溢出
        for i in 0..<sortedLines.count {
            if i < sortedLines.count - 1 {
                let diff = sortedLines[i + 1].time - sortedLines[i].time
                let textLength = Double(sortedLines[i].text.count)
                let estimatedSingTime = max(1.2, min(diff - 0.4, textLength * 0.32))
                sortedLines[i].duration = max(1.0, estimatedSingTime)
            } else {
                sortedLines[i].duration = 5.0
            }
        }

        return sortedLines
    }

    private func attachTranslation(to lines: inout [LyricLine], translation: String?) {
        guard let trans = translation, !trans.isEmpty else { return }
        let pattern = /\[(\d{2}):(\d{2})(?:\.(\d{2,3}))?\](.*)/
        var transDict: [Int: String] = [:]

        for rawLine in trans.components(separatedBy: .newlines) {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            if let match = trimmed.firstMatch(of: pattern) {
                let min = Double(match.1) ?? 0
                let sec = Double(match.2) ?? 0
                let msStr = match.3.map(String.init) ?? "0"
                let ms = (Double(msStr) ?? 0) / (msStr.count == 3 ? 1000.0 : 100.0)
                let timeMs = Int((min * 60 + sec + ms) * 10)
                let text = String(match.4).trimmingCharacters(in: .whitespaces)
                if !text.isEmpty {
                    transDict[timeMs] = text
                }
            }
        }

        for i in 0..<lines.count {
            let key = Int(lines[i].time * 10)
            for offset in [-3, -2, -1, 0, 1, 2, 3] {
                if let t = transDict[key + offset] {
                    lines[i].translation = t
                    break
                }
            }
        }
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
                let success = try await NetworkManager.shared.likeSong(id: song.id, like: !currentlyLiked)
                if !success {
                    // 回滚
                    await MainActor.run {
                        if currentlyLiked {
                            self.likedSongIds.insert(song.id)
                        } else {
                            self.likedSongIds.remove(song.id)
                        }
                    }
                }
            } catch {
                print("点赞操作失败: \(error)")
                await MainActor.run {
                    if currentlyLiked {
                        self.likedSongIds.insert(song.id)
                    } else {
                        self.likedSongIds.remove(song.id)
                    }
                }
            }
        }
    }

    func loadLikedSongs(uid: Int) async {
        do {
            let ids = try await NetworkManager.shared.likeList(uid: uid)
            likedSongIds = Set(ids)
        } catch {
            print("加载喜欢列表失败: \(error)")
        }
    }

    // MARK: - Queue Management

    func addToPlaylist(_ song: APISong) {
        if !playlist.contains(where: { $0.id == song.id }) {
            playlist.append(song)
        }
    }

    func playNext(_ song: APISong) {
        if let idx = playlist.firstIndex(where: { $0.id == song.id }) {
            playlist.remove(at: idx)
        }
        let insertIdx = min(currentIndex + 1, playlist.count)
        playlist.insert(song, at: insertIdx)
    }

    func removeFromPlaylist(at index: Int) {
        guard index >= 0 && index < playlist.count else { return }
        playlist.remove(at: index)
        if index < currentIndex {
            currentIndex -= 1
        } else if index == currentIndex {
            if !playlist.isEmpty {
                currentIndex = min(currentIndex, playlist.count - 1)
                play(playlist[currentIndex])
            } else {
                pause()
                currentSong = nil
                currentIndex = -1
                updateNowPlaying()
            }
        }
    }

    func removeFromPlaylist(song: APISong) {
        if let idx = playlist.firstIndex(where: { $0.id == song.id }) {
            removeFromPlaylist(at: idx)
        }
    }

    func clearQueue() {
        if let current = currentSong {
            playlist = [current]
            currentIndex = 0
        } else {
            playlist.removeAll()
            currentIndex = -1
        }
    }

    func clearPlaylist() {
        playlist.removeAll()
        currentIndex = -1
        pause()
        currentSong = nil
        updateNowPlaying()
    }

    // MARK: - Playback Controls

    func pause() {
        player.pause()
        isPlaying = false
        updateNowPlaying()
    }

    func resume() {
        player.play()
        isPlaying = true
        updateNowPlaying()
    }

    func togglePlay() {
        if isPlaying {
            player.pause()
            isPlaying = false
            updateNowPlaying()
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
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        if !finished || self.player.currentItem?.status == .failed {
                            if let song = self.currentSong {
                                self.play(song)
                                return
                            }
                        }
                        self.player.play()
                        self.isPlaying = true
                        self.updateNowPlaying()
                    }
                }
                isPlaying = true
                updateNowPlaying()
                return
            }

            player.play()
            isPlaying = true
            updateNowPlaying()
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
            updateNowPlaying()
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

    // MARK: - Media Center & Now Playing Integration

    private func updateNowPlaying() {
        guard let song = currentSong else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }

        var info: [String: Any] = [
            MPMediaItemPropertyTitle: song.name,
            MPMediaItemPropertyArtist: song.displayArtist,
            MPMediaItemPropertyAlbumTitle: song.displayAlbum,
            MPMediaItemPropertyPlaybackDuration: duration > 0 ? duration : Double(song.durationMs) / 1000.0,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]

        if let currentInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo,
           let artwork = currentInfo[MPMediaItemPropertyArtwork] {
            info[MPMediaItemPropertyArtwork] = artwork
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func fetchArtwork(for song: APISong) {
        // 1. 优先检查本地封面 (已下载歌曲或本地导入歌曲)
        if let localCoverURL = DownloadManager.shared.localCoverURL(for: song.id),
           let nsImage = NSImage(contentsOf: localCoverURL) {
            var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
            let artwork = MPMediaItemArtwork(boundsSize: nsImage.size) { _ in nsImage }
            info[MPMediaItemPropertyArtwork] = artwork
            MPNowPlayingInfoCenter.default().nowPlayingInfo = info
            return
        }

        // 2. 本地不存在，异步拉取网络封面
        guard let coverUrl = song.coverUrl, let url = URL(string: coverUrl) else { return }
        Task { [weak self] in
            guard let (data, _) = try? await URLSession.shared.data(from: url),
                  let nsImage = NSImage(data: data) else { return }
            await MainActor.run { [weak self] in
                guard let self = self, self.currentSong?.id == song.id else { return }
                var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
                let artwork = MPMediaItemArtwork(boundsSize: nsImage.size) { _ in nsImage }
                info[MPMediaItemPropertyArtwork] = artwork
                MPNowPlayingInfoCenter.default().nowPlayingInfo = info
            }
        }
    }

    private func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()

        center.playCommand.isEnabled = true
        center.playCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.resume() }
            return .success
        }

        center.pauseCommand.isEnabled = true
        center.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.pause() }
            return .success
        }

        center.togglePlayPauseCommand.isEnabled = true
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.togglePlay() }
            return .success
        }

        center.nextTrackCommand.isEnabled = true
        center.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.next() }
            return .success
        }

        center.previousTrackCommand.isEnabled = true
        center.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.previous() }
            return .success
        }

        center.changePlaybackPositionCommand.isEnabled = true
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let posEvent = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            Task { @MainActor [weak self] in self?.seek(to: posEvent.positionTime) }
            return .success
        }
    }

    // MARK: - Observers

    private func setupTimeObserver() {
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.05, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            MainActor.assumeIsolated {
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
    }

    private func setupEndObserver() {
        NotificationCenter.default.addObserver(
            forName: AVPlayerItem.didPlayToEndTimeNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            MainActor.assumeIsolated {
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
                        Task { @MainActor [weak self] in
                            self?.player.play()
                            self?.isPlaying = true
                            self?.updateNowPlaying()
                        }
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
                        self.updateNowPlaying()
                    }
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

    // MARK: - 音质即时无缝切换重载

    func reloadCurrentSongWithNewQuality() async {
        guard let song = currentSong, song.id > 0 else { return }
        let currentPos = currentTime
        let wasPlaying = isPlaying
        isLoading = true
        do {
            var urlStr = try await NetworkManager.shared.songURL(id: song.id, level: soundQuality.rawValue)
            if urlStr == nil || urlStr?.isEmpty == true {
                urlStr = try await NetworkManager.shared.songURL(id: song.id, level: "standard")
            }
            if urlStr == nil || urlStr?.isEmpty == true {
                urlStr = try await NetworkManager.shared.songURLMatch(id: song.id)
            }

            guard let finalUrl = urlStr, let url = URL(string: finalUrl) else {
                isLoading = false
                return
            }

            let item = AVPlayerItem(url: url)
            itemStatusObserver = item.observe(\.status, options: [.new]) { [weak self] observedItem, _ in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    if observedItem.status == .failed {
                        let errMsg = observedItem.error?.localizedDescription ?? "未知错误"
                        print("❌ 音频加载失败: \(errMsg)")
                        self.isPlaying = false
                        self.isLoading = false
                        self.updateNowPlaying()
                    }
                }
            }
            player.replaceCurrentItem(with: item)
            if currentPos > 0 {
                await player.seek(to: CMTime(seconds: currentPos, preferredTimescale: 600))
            }
            if wasPlaying {
                player.play()
                isPlaying = true
            }
            isLoading = false
            updateNowPlaying()
        } catch {
            print("❌ 切换音质重新加载失败: \(error)")
            isLoading = false
        }
    }
}

// MARK: - SoundQualityType 扩展展示

extension SoundQualityType {
    public var displayName: String {
        switch self {
        case .standard: return "标准 (128K)".localized
        case .exhigh:   return "极高 (320K)".localized
        case .lossless: return "无损 (FLAC)".localized
        case .hires:    return "Hi-Res".localized
        case .jyeffect: return "高清环绕声".localized
        case .sky:      return "沉浸环绕声".localized
        case .jymaster: return "超清母带".localized
        }
    }

    public var shortBadge: String {
        switch self {
        case .standard: return "标准"
        case .exhigh:   return "极高"
        case .lossless: return "无损"
        case .hires:    return "Hi-Res"
        case .jyeffect: return "环绕声"
        case .sky:      return "沉浸声"
        case .jymaster: return "母带"
        }
    }
}
