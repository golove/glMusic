//
//  PlayerManager.swift
//  glMusic
//
//  Created by go love on 10/23/26.
//

import SwiftUI
import AVFoundation
import MediaPlayer
import CoreImage
import NeteaseCloudMusicAPI

@MainActor
@Observable
final class PlayerManager {

    // MARK: - Playback State

    var currentSong: APISong?
    var currentBlurredArtwork: NSImage?
    var isPlaying: Bool = false
    var currentTime: TimeInterval = 0
    var duration: TimeInterval = 0
    var volume: Double = 0.7 {
        didSet {
            UserDefaults.standard.set(volume, forKey: "player_volume")
            if !isCrossfading {
                player.volume = Float(volume)
            }
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

    // MARK: - Crossfade Engine (音频平滑交叉渐变)

    var isCrossfadeEnabled: Bool = UserDefaults.standard.object(forKey: "player_crossfade_enabled") == nil ? true : UserDefaults.standard.bool(forKey: "player_crossfade_enabled") {
        didSet {
            UserDefaults.standard.set(isCrossfadeEnabled, forKey: "player_crossfade_enabled")
        }
    }
    var crossfadeDuration: Double = {
        let val = UserDefaults.standard.double(forKey: "player_crossfade_duration")
        return val > 0 ? val : 3.0
    }() {
        didSet {
            UserDefaults.standard.set(crossfadeDuration, forKey: "player_crossfade_duration")
        }
    }
    private var fadePlayer = AVPlayer()
    private var isCrossfading: Bool = false
    private var crossfadeTask: Task<Void, Never>?

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
    private var currentPlaybackTask: Task<Void, Never>?

    // MARK: - Preloading & Fault-Tolerance Engine

    private var preloadedSongId: Int?
    private var preloadedItem: AVPlayerItem?
    private var preloadedLyrics: [LyricLine]?
    private var preloadingTask: Task<Void, Never>?
    private var failureConsecutiveCount: Int = 0

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
        player.automaticallyWaitsToMinimizeStalling = true
        fadePlayer.automaticallyWaitsToMinimizeStalling = true

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
        cancelCrossfade()
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

        currentPlaybackTask?.cancel()
        currentPlaybackTask = Task {
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
        cancelCrossfade()
        currentTime = min(max(time, 0), duration)
        player.seek(to: CMTime(seconds: currentTime, preferredTimescale: 600))
        updateNowPlaying()
        if duration > 15 && (duration - currentTime) > 15 {
            invalidatePreload()
        }
    }

    private func setupItemStatusObserver(for item: AVPlayerItem, songId: Int) {
        itemStatusObserver = item.observe(\.status, options: [.new]) { [weak self] observedItem, _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if observedItem.status == .failed {
                    let errMsg = observedItem.error?.localizedDescription ?? "未知错误"
                    print("❌ 音频加载失败 (songId: \(songId)): \(errMsg)")
                    self.isPlaying = false
                    self.isLoading = false
                    self.updateNowPlaying()
                    self.handlePlaybackFailure(for: songId)
                }
            }
        }
    }

    private func handlePlaybackFailure(for songId: Int) {
        failureConsecutiveCount += 1
        guard failureConsecutiveCount <= 3, playlist.count > 1 else {
            failureConsecutiveCount = 0
            return
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1500))
            if self.currentSong?.id == songId && !self.isPlaying {
                print("⚠️ [glMusic] 歌曲播放异常，防呆机制启动：自动跳至下一首有效歌曲")
                self.next()
            }
        }
    }

    /// 平滑无爆音切换至新音频项目 (包含 20ms 快速淡出旧音轨 + 静音切轨 + 35ms 优雅微淡入新音轨，彻底消灭波形截断爆音与电台杂音)
    private func smoothlyTransitionToItem(_ item: AVPlayerItem, forSongId songId: Int) async {
        guard currentSong?.id == songId else { return }

        // 1. 若当前正在发声，在 20ms 内快速平滑降至 0 音量并暂停旧音频，彻底消灭波形突变产生的爆音/电台杂音
        if player.timeControlStatus == .playing && player.volume > 0.05 {
            let startVol = player.volume
            let fadeOutSteps = 4
            for step in 1...fadeOutSteps {
                let factor = Float(fadeOutSteps - step) / Float(fadeOutSteps)
                player.volume = startVol * factor
                try? await Task.sleep(for: .milliseconds(5))
            }
            player.volume = 0
            player.pause()
        }

        guard currentSong?.id == songId else { return }

        // 2. 配置新项目的防抖预缓冲
        item.preferredForwardBufferDuration = 2.0
        item.canUseNetworkResourcesForLiveStreamingWhilePaused = true

        // 3. 静音状态下挂载新项目 (0 杂音、0 杂波冲击声卡 DAC)
        setupItemStatusObserver(for: item, songId: songId)
        player.replaceCurrentItem(with: item)

        // 4. 起播并在 35ms 内由 0 优雅淡入到目标设定音量
        player.play()
        isPlaying = true
        isLoading = false
        failureConsecutiveCount = 0
        updateNowPlaying()

        let targetVol = Float(volume)
        if targetVol > 0 {
            let fadeInSteps = 5
            for step in 1...fadeInSteps {
                try? await Task.sleep(for: .milliseconds(7))
                guard currentSong?.id == songId else { return }
                let factor = Float(step) / Float(fadeInSteps)
                player.volume = targetVol * factor
            }
            player.volume = targetVol
        }
    }

    private func loadAndPlay(songId: Int) async {
        // 0. 优先命中预加载缓冲池：达成 0ms 瞬间换轨与无缝起播
        if preloadedSongId == songId, let item = preloadedItem {
            #if DEBUG
            print("🚀 [glMusic] 命中预加载缓冲池，实现 0ms 瞬间换轨: 《\(currentSong?.name ?? "")》 (ID: \(songId))")
            #endif
            self.preloadedSongId = nil
            self.preloadedItem = nil

            await smoothlyTransitionToItem(item, forSongId: songId)
            return
        }

        // 1. 优先检查本地是否已下载：支持完全离线播放、0 秒缓冲与无损本地解码
        if let localURL = DownloadManager.shared.localAudioURL(for: songId) {
            print("💾 播放本地已下载音频: \(currentSong?.name ?? "") → \(localURL.lastPathComponent)")
            guard currentSong?.id == songId else { return }
            let item = AVPlayerItem(url: localURL)
            await smoothlyTransitionToItem(item, forSongId: songId)
            return
        }

        // 2. 检查本地在线流媒体磁盘缓存（边播边存，二次收听 0 缓冲、0 流量、秒起播）
        if let cachedURL = await StreamingCacheManager.shared.cachedAudioURL(for: songId) {
            print("💾 播放本地流媒体缓存音频: \(currentSong?.name ?? "") → \(cachedURL.lastPathComponent)")
            guard currentSong?.id == songId else { return }
            let item = AVPlayerItem(url: cachedURL)
            await smoothlyTransitionToItem(item, forSongId: songId)
            return
        }

        // 3. 本地未下载且未缓存：若为本地导入歌曲 (songId < 0) 且本地文件不存在，直接提示错误，不请求网络
        if songId < 0 {
            print("❌ 本地导入音频文件不存在或已被移动 (songId: \(songId))")
            isPlaying = false
            isLoading = false
            updateNowPlaying()
            handlePlaybackFailure(for: songId)
            return
        }

        // 4. 走网络流媒体加载
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
                handlePlaybackFailure(for: songId)
                return
            }

            // 确保切歌时旧的网络请求不会覆盖当前最新的歌曲
            guard currentSong?.id == songId else { return }

            print("▶️ 播放: \(currentSong?.name ?? "") → \(finalUrl.prefix(80))...")
            let item = AVPlayerItem(url: url)
            await smoothlyTransitionToItem(item, forSongId: songId)

            // 启动流媒体边播边存后台静默缓存
            Task {
                await StreamingCacheManager.shared.cacheSongIfNeeded(songId: songId, remoteURL: url)
            }
        } catch {
            print("❌ 播放失败: \(error)")
            isLoading = false
            updateNowPlaying()
            handlePlaybackFailure(for: songId)
        }
    }

    // MARK: - Preloading Engine (下一首音频毫秒级预加载)

    func getNextSong() -> APISong? {
        guard !playlist.isEmpty else { return nil }
        if repeatMode == .one {
            return currentSong
        }
        if isShuffled {
            if playlist.count == 1 { return playlist.first }
            let otherIndices = playlist.indices.filter { $0 != currentIndex }
            if let randomIdx = otherIndices.randomElement() {
                return playlist[randomIdx]
            }
            return playlist.first
        } else {
            let nextIdx = (currentIndex + 1) % playlist.count
            return playlist[nextIdx]
        }
    }

    private func triggerPreloadNextSongIfNeeded() {
        guard let nextSong = getNextSong(), nextSong.id != currentSong?.id else { return }
        if preloadedSongId == nextSong.id || preloadingTask != nil { return }

        preloadingTask = Task { [weak self] in
            guard let self = self else { return }
            await self.preloadSong(nextSong)
        }
    }

    private func preloadSong(_ song: APISong) async {
        var targetItem: AVPlayerItem? = nil

        // 预取音频直链（依次检查：离线下载 -> 本地流媒体磁盘缓存 -> 异步直链解析）
        if let localURL = DownloadManager.shared.localAudioURL(for: song.id) {
            targetItem = AVPlayerItem(url: localURL)
        } else if let cachedURL = await StreamingCacheManager.shared.cachedAudioURL(for: song.id) {
            targetItem = AVPlayerItem(url: cachedURL)
        } else if song.id > 0 {
            do {
                var urlStr = try await NetworkManager.shared.songURL(id: song.id, level: soundQuality.rawValue)
                if urlStr == nil || urlStr?.isEmpty == true {
                    urlStr = try await NetworkManager.shared.songURL(id: song.id, level: "standard")
                }
                if urlStr == nil || urlStr?.isEmpty == true {
                    urlStr = try await NetworkManager.shared.songURLMatch(id: song.id)
                }
                if let finalUrl = urlStr, let url = URL(string: finalUrl) {
                    targetItem = AVPlayerItem(url: url)
                }
            } catch {
                #if DEBUG
                print("⚠️ [glMusic] 预解析下一首直链异常: \(error)")
                #endif
            }
        }

        // 预取歌词并解析
        var targetLyrics: [LyricLine]? = nil
        if let localLrc = DownloadManager.shared.localLyrics(for: song.id) {
            let localTrans = DownloadManager.shared.localTranslation(for: song.id)
            targetLyrics = parseLyrics(yrc: nil, lrc: localLrc, translation: localTrans)
        } else if song.id > 0 {
            if let resp = try? await NetworkManager.shared.lyrics(id: song.id) {
                targetLyrics = parseLyrics(yrc: resp.yrc?.lyric, lrc: resp.lrc?.lyric, translation: resp.tlyric?.lyric)
            }
        }

        guard let item = targetItem else {
            self.preloadingTask = nil
            return
        }

        if self.currentSong?.id != song.id {
            self.preloadedSongId = song.id
            self.preloadedItem = item
            self.preloadedLyrics = targetLyrics
            #if DEBUG
            print("⚡️ [glMusic] 下一首音频与歌词预加载就绪: 《\(song.name)》 (ID: \(song.id))")
            #endif
        }
        self.preloadingTask = nil
    }

    func invalidatePreload() {
        cancelCrossfade()
        preloadingTask?.cancel()
        preloadingTask = nil
        preloadedSongId = nil
        preloadedItem = nil
        preloadedLyrics = nil
    }

    // MARK: - Lyrics Loading & Parsing

    func loadLyrics(for songId: Int) async {
        // 0. 优先命中预加载歌词
        if preloadedSongId == songId, let lyrics = preloadedLyrics, !lyrics.isEmpty {
            self.lyrics = lyrics
            self.currentLyricIndex = 0
            self.isLoadingLyrics = false
            self.preloadedLyrics = nil
            return
        }

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
            invalidatePreload()
        }
    }

    func playNext(_ song: APISong) {
        if let idx = playlist.firstIndex(where: { $0.id == song.id }) {
            playlist.remove(at: idx)
        }
        let insertIdx = min(currentIndex + 1, playlist.count)
        playlist.insert(song, at: insertIdx)
        invalidatePreload()
    }

    func removeFromPlaylist(at index: Int) {
        guard index >= 0 && index < playlist.count else { return }
        playlist.remove(at: index)
        invalidatePreload()
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

    func movePlaylistSong(fromIndex: Int, toIndex: Int) {
        guard fromIndex >= 0 && fromIndex < playlist.count,
              toIndex >= 0 && toIndex < playlist.count,
              fromIndex != toIndex else { return }
        let song = playlist.remove(at: fromIndex)
        playlist.insert(song, at: toIndex)
        if let current = currentSong, let newIdx = playlist.firstIndex(where: { $0.id == current.id }) {
            currentIndex = newIdx
        }
        invalidatePreload()
    }

    func moveSongToTop(_ song: APISong) {
        guard let idx = playlist.firstIndex(where: { $0.id == song.id }), idx > 0 else { return }
        movePlaylistSong(fromIndex: idx, toIndex: 0)
    }

    func moveSongToBottom(_ song: APISong) {
        guard let idx = playlist.firstIndex(where: { $0.id == song.id }), idx < playlist.count - 1 else { return }
        movePlaylistSong(fromIndex: idx, toIndex: playlist.count - 1)
    }

    func clearQueue() {
        if let current = currentSong {
            playlist = [current]
            currentIndex = 0
        } else {
            playlist.removeAll()
            currentIndex = -1
        }
        invalidatePreload()
    }

    func clearPlaylist() {
        playlist.removeAll()
        currentIndex = -1
        pause()
        currentSong = nil
        invalidatePreload()
        updateNowPlaying()
    }

    // MARK: - Playback Controls

    func pause() {
        cancelCrossfade()
        currentPlaybackTask?.cancel()
        if player.timeControlStatus == .playing && player.volume > 0.05 {
            let startVol = player.volume
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                for step in 1...3 {
                    self.player.volume = startVol * Float(3 - step) / 3.0
                    try? await Task.sleep(for: .milliseconds(5))
                }
                self.player.pause()
                self.player.volume = Float(self.volume)
            }
        } else {
            player.pause()
        }
        isPlaying = false
        updateNowPlaying()
    }

    func resume() {
        let targetVol = Float(volume)
        player.volume = 0
        player.play()
        isPlaying = true
        updateNowPlaying()
        if targetVol > 0 {
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                for step in 1...4 {
                    try? await Task.sleep(for: .milliseconds(6))
                    self.player.volume = targetVol * Float(step) / 4.0
                }
                self.player.volume = targetVol
            }
        }
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

    func toggleShuffle() {
        isShuffled.toggle()
        invalidatePreload()
    }

    func cycleRepeat() {
        switch repeatMode {
        case .off:  repeatMode = .all
        case .all:  repeatMode = .one
        case .one:  repeatMode = .off
        }
        invalidatePreload()
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
            applyArtwork(nsImage, for: song)
            return
        }

        // 2. 本地不存在，异步拉取网络封面
        guard let coverUrl = song.coverUrl, let url = URL(string: coverUrl) else {
            self.currentBlurredArtwork = nil
            return
        }
        Task { [weak self] in
            guard let (data, _) = try? await URLSession.shared.data(from: url),
                  let nsImage = NSImage(data: data) else { return }
            await MainActor.run { [weak self] in
                guard let self = self, self.currentSong?.id == song.id else { return }
                self.applyArtwork(nsImage, for: song)
            }
        }
    }

    private func applyArtwork(_ nsImage: NSImage, for song: APISong) {
        var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        let artwork = MPMediaItemArtwork(boundsSize: nsImage.size) { _ in nsImage }
        info[MPMediaItemPropertyArtwork] = artwork
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info

        // 异步预生成高斯模糊背景小图 (140x140，单次 GPU 耗时 < 1.5ms，彻底消灭全屏实时 65px 模糊滤镜对 GPU/CPU 的压榨)
        Task.detached(priority: .userInitiated) { [weak self] in
            let blurred = Self.createBlurredArtwork(from: nsImage)
            await MainActor.run { [weak self] in
                guard let self = self, self.currentSong?.id == song.id else { return }
                self.currentBlurredArtwork = blurred
            }
        }
    }

    nonisolated private static let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    nonisolated private static func createBlurredArtwork(from image: NSImage) -> NSImage? {
        guard let tiffData = image.tiffRepresentation,
              let ciImage = CIImage(data: tiffData) else { return nil }

        let extent = ciImage.extent
        guard extent.width > 0 && extent.height > 0 else { return nil }

        let targetSize: CGFloat = 140.0
        let scale = targetSize / max(extent.width, extent.height)
        let scaledImage = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        let clamped = scaledImage.clampedToExtent()
        guard let filter = CIFilter(name: "CIGaussianBlur") else { return nil }
        filter.setValue(clamped, forKey: kCIInputImageKey)
        filter.setValue(16.0, forKey: kCIInputRadiusKey)

        guard let output = filter.outputImage else { return nil }
        let cropped = output.cropped(to: CGRect(x: 0, y: 0, width: targetSize, height: targetSize))

        guard let cgImage = ciContext.createCGImage(cropped, from: cropped.extent) else { return nil }
        return NSImage(cgImage: cgImage, size: NSSize(width: targetSize, height: targetSize))
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
            forInterval: CMTime(seconds: 0.1, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            MainActor.assumeIsolated {
                guard let self else { return }
                let t = time.seconds
                if t.isFinite {
                    self.currentTime = t
                    if !self.lyrics.isEmpty {
                        let count = self.lyrics.count
                        let curr = self.currentLyricIndex
                        if curr >= 0 && curr < count && self.lyrics[curr].time <= t && (curr + 1 >= count || self.lyrics[curr + 1].time > t) {
                            // 依然在当前行，O(1) 零计算开销
                        } else if curr + 1 < count && self.lyrics[curr + 1].time <= t && (curr + 2 >= count || self.lyrics[curr + 2].time > t) {
                            self.currentLyricIndex = curr + 1
                        } else if let idx = self.lyrics.lastIndex(where: { $0.time <= t }) {
                            if self.currentLyricIndex != idx {
                                self.currentLyricIndex = idx
                            }
                        } else {
                            self.currentLyricIndex = 0
                        }
                    }

                    // 距离当前曲目播完最后 15 秒以内时，自动在后台静默预加载下一首歌曲直链与歌词
                    if self.duration > 15 && (self.duration - t) <= 15 {
                        self.triggerPreloadNextSongIfNeeded()
                    }

                    // 检查是否触发歌曲末尾音频平滑交叉渐变 (Crossfade)
                    if self.isCrossfadeEnabled && !self.isCrossfading && self.duration > 8 && self.repeatMode != .one {
                        let remaining = self.duration - t
                        if remaining <= self.crossfadeDuration && remaining >= 0.5 {
                            self.triggerNaturalCrossfade()
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
        invalidatePreload()
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
            setupItemStatusObserver(for: item, songId: song.id)
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

    // MARK: - Crossfade Execution (交叉渐变实现)

    private func triggerNaturalCrossfade() {
        guard let nextSong = getNextSong(), nextSong.id != currentSong?.id else { return }
        isCrossfading = true
        #if DEBUG
        print("🔀 [glMusic] 触发歌曲末尾平滑交叉渐变: 《\(currentSong?.name ?? "")》 ➔ 《\(nextSong.name)》 (时长: \(crossfadeDuration)s)")
        #endif

        crossfadeTask = Task { @MainActor [weak self] in
            guard let self = self else { return }

            // 准备下一首歌曲的 AVPlayerItem
            var nextItem: AVPlayerItem? = nil
            if self.preloadedSongId == nextSong.id, let item = self.preloadedItem {
                nextItem = item
                self.preloadedItem = nil
                self.preloadedSongId = nil
            } else if let localURL = DownloadManager.shared.localAudioURL(for: nextSong.id) {
                nextItem = AVPlayerItem(url: localURL)
            } else if let cachedURL = await StreamingCacheManager.shared.cachedAudioURL(for: nextSong.id) {
                nextItem = AVPlayerItem(url: cachedURL)
            } else {
                if let urlStr = try? await NetworkManager.shared.songURL(id: nextSong.id, level: self.soundQuality.rawValue),
                   let url = URL(string: urlStr) {
                    nextItem = AVPlayerItem(url: url)
                }
            }

            guard let incomingItem = nextItem, self.isCrossfading else {
                self.isCrossfading = false
                return
            }

            // 初始化淡入播放器
            self.fadePlayer.replaceCurrentItem(with: incomingItem)
            self.fadePlayer.volume = 0.0
            self.fadePlayer.play()

            let steps = max(10, Int(self.crossfadeDuration * 20))
            let sleepMs = UInt64((self.crossfadeDuration / Double(steps)) * 1000)

            for step in 1...steps {
                try? await Task.sleep(nanoseconds: sleepMs * 1_000_000)
                guard self.isCrossfading else { return }
                let progress = Double(step) / Double(steps)
                self.player.volume = Float(max(0, (1.0 - progress) * self.volume))
                self.fadePlayer.volume = Float(min(self.volume, progress * self.volume))
            }

            self.finishCrossfade(to: nextSong, with: incomingItem)
        }
    }

    private func finishCrossfade(to nextSong: APISong, with item: AVPlayerItem) {
        guard isCrossfading else { return }

        // 停止原主播放器
        player.pause()
        if let currentObs = timeObserver {
            player.removeTimeObserver(currentObs)
            timeObserver = nil
        }

        // 交换主次播放器
        let oldPlayer = player
        player = fadePlayer
        fadePlayer = oldPlayer

        fadePlayer.replaceCurrentItem(with: nil)
        fadePlayer.volume = 0.0
        player.volume = Float(volume)

        // 重新挂载监听
        setupTimeObserver()
        setupItemStatusObserver(for: item, songId: nextSong.id)

        // 更新状态
        currentSong = nextSong
        duration = Double(nextSong.durationMs) / 1000.0
        currentTime = player.currentTime().seconds
        if let idx = playlist.firstIndex(where: { $0.id == nextSong.id }) {
            currentIndex = idx
        }
        HistoryManager.shared.record(song: nextSong)
        UserDefaults.standard.set(nextSong.id, forKey: "last_played_song_id")
        updateNowPlaying()
        fetchArtwork(for: nextSong)

        Task {
            await loadLyrics(for: nextSong.id)
        }

        isCrossfading = false
        crossfadeTask = nil
        #if DEBUG
        print("✅ [glMusic] 交叉渐变平滑完成，现已无缝过渡至: 《\(nextSong.name)》")
        #endif
    }

    func cancelCrossfade() {
        crossfadeTask?.cancel()
        crossfadeTask = nil
        fadePlayer.pause()
        fadePlayer.replaceCurrentItem(with: nil)
        fadePlayer.volume = 0.0
        player.volume = Float(volume)
        isCrossfading = false
    }

    func toggleCrossfade() {
        isCrossfadeEnabled.toggle()
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
