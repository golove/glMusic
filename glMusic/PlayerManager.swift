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
    /// 独立 1Hz 秒级更新状态：专供界面时间文本（currentTimeText / remainingTimeText）绑定，消除 10Hz 无效文本重排
    var currentSecond: Int = 0
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
    private var crossfadingTargetSong: APISong?
    private var crossfadingTargetItem: AVPlayerItem?

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

    // MARK: - AVPlayer & Session Management

    private var player = AVPlayer()
    private var timeObserver: Any?
    private var itemStatusObserver: NSKeyValueObservation?
    private var currentPlaybackTask: Task<Void, Never>?
    /// 播放会话代次标识：防止切歌过快时旧网络/解码任务覆盖新歌曲状态
    private var currentSessionId = UUID()

    // MARK: - Preloading & Fault-Tolerance Engine

    private var preloadedSongId: Int?
    private var preloadedItem: AVPlayerItem?
    private var preloadedLyrics: [LyricLine]?
    private var preloadingTask: Task<Void, Never>?
    private var preloadRequestId = UUID()
    private var failureConsecutiveCount: Int = 0

    // MARK: - Computed

    var progress: Double {
        get { duration > 0 ? currentTime / duration : 0 }
        set {
            let target = newValue * duration
            currentTime = target
            currentSecond = Int(target)
            player.seek(to: CMTime(seconds: target, preferredTimescale: 600))
            updateNowPlaying()
        }
    }

    var currentTimeText: String { formatTime(Double(currentSecond)) }
    var remainingTimeText: String { "-" + formatTime(max(0, duration - Double(currentSecond))) }

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

    isolated deinit {
        if let observer = timeObserver {
            player.removeTimeObserver(observer)
        }
        itemStatusObserver?.invalidate()
    }

    // MARK: - Play Song

    func play(_ song: APISong) {
        cancelCrossfade()
        let sessionId = UUID()
        self.currentSessionId = sessionId

        currentSong = song
        duration = Double(song.durationMs) / 1000.0
        currentTime = 0
        currentSecond = 0
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
        fetchArtwork(for: song, sessionId: sessionId)

        currentPlaybackTask?.cancel()
        currentPlaybackTask = Task {
            async let playTask: Void = loadAndPlay(songId: song.id, sessionId: sessionId)
            async let lyricTask: Void = loadLyrics(for: song.id, sessionId: sessionId)
            _ = await (playTask, lyricTask)
        }
    }

    func playAll(_ songs: [APISong], from index: Int = 0) {
        guard !songs.isEmpty else { return }
        playlist = songs
        let targetIndex = songs.indices.contains(index) ? index : 0
        currentIndex = targetIndex
        if songs.indices.contains(targetIndex) {
            play(songs[targetIndex])
        }
    }

    func seek(to time: TimeInterval) {
        cancelCrossfade()
        currentTime = min(max(time, 0), duration)
        currentSecond = Int(currentTime)
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

    /// 平滑无爆音切换至新音频项目 (包含 25ms 快速平滑淡出旧音轨 + 纯绝对静音切轨 + 35ms 优雅微淡入新音轨，彻底消灭波形截断爆音与电台杂音)
    private func smoothlyTransitionToItem(_ item: AVPlayerItem, forSongId songId: Int) async {
        guard currentSong?.id == songId else { return }

        // 1. 若当前正在发声，在 20ms 内快速平滑降至 0 音量并暂停旧音频，彻底消灭波形突变产生的爆音/电台杂音
        if (player.timeControlStatus == .playing || player.rate > 0) && player.volume > 0.02 {
            let startVol = player.volume
            let fadeOutSteps = 5
            for step in 1...fadeOutSteps {
                let factor = Float(fadeOutSteps - step) / Float(fadeOutSteps)
                player.volume = startVol * factor
                try? await Task.sleep(for: .milliseconds(4))
            }
        }

        // 确保无论先前处于何种播放状态，切轨前必须保证处于 0 音量静音与暂停状态
        player.volume = 0
        player.pause()

        guard currentSong?.id == songId else { return }

        // 2. 配置新项目的防抖预缓冲
        item.preferredForwardBufferDuration = 2.0
        item.canUseNetworkResourcesForLiveStreamingWhilePaused = true

        // 3. 绝对静音状态下挂载新项目 (0 杂音、0 杂波冲击声卡 DAC)
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

    private func loadAndPlay(songId: Int, sessionId: UUID) async {
        // 0. 优先命中预加载缓冲池：达成 0ms 瞬间换轨与无缝起播
        if preloadedSongId == songId, let item = preloadedItem {
            #if DEBUG
            print("🚀 [glMusic] 命中预加载缓冲池，实现 0ms 瞬间换轨: 《\(currentSong?.name ?? "")》 (ID: \(songId))")
            #endif
            self.preloadedSongId = nil
            self.preloadedItem = nil

            guard self.currentSessionId == sessionId else { return }
            await smoothlyTransitionToItem(item, forSongId: songId)
            return
        }

        // 1. 优先检查本地是否已下载：支持完全离线播放、0 秒缓冲与无损本地解码
        if let localURL = DownloadManager.shared.localAudioURL(for: songId) {
            print("💾 播放本地已下载音频: \(currentSong?.name ?? "") → \(localURL.lastPathComponent)")
            guard self.currentSessionId == sessionId && currentSong?.id == songId else { return }
            let item = AVPlayerItem(url: localURL)
            await smoothlyTransitionToItem(item, forSongId: songId)
            return
        }

        // 2. 检查本地在线流媒体磁盘缓存（边播边存，二次收听 0 缓冲、0 流量、秒起播）
        if let cachedURL = await StreamingCacheManager.shared.cachedAudioURL(for: songId) {
            print("💾 播放本地流媒体缓存音频: \(currentSong?.name ?? "") → \(cachedURL.lastPathComponent)")
            guard self.currentSessionId == sessionId && currentSong?.id == songId else { return }
            let item = AVPlayerItem(url: cachedURL)
            await smoothlyTransitionToItem(item, forSongId: songId)
            return
        }

        // 3. 本地未下载且未缓存：若为本地导入歌曲 (songId < 0) 且本地文件不存在，直接提示错误，不请求网络
        if songId < 0 {
            guard self.currentSessionId == sessionId else { return }
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
                guard self.currentSessionId == sessionId else { return }
                print("⚠️ 歌曲 \(songId) 无可用 URL，自动跳过")
                isLoading = false
                handlePlaybackFailure(for: songId)
                return
            }

            // 确保切歌时旧的网络请求不会覆盖当前最新的歌曲
            guard self.currentSessionId == sessionId && currentSong?.id == songId else { return }

            print("▶️ 播放: \(currentSong?.name ?? "") → \(finalUrl.prefix(80))...")
            let item = AVPlayerItem(url: url)
            await smoothlyTransitionToItem(item, forSongId: songId)

            // 启动流媒体边播边存后台静默缓存
            Task {
                await StreamingCacheManager.shared.cacheSongIfNeeded(songId: songId, remoteURL: url)
            }
        } catch {
            guard self.currentSessionId == sessionId else { return }
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

        let requestId = UUID()
        preloadRequestId = requestId
        preloadingTask = Task { [weak self] in
            guard let self = self else { return }
            await self.preloadSong(nextSong, requestId: requestId)
        }
    }

    private func preloadSong(_ song: APISong, requestId: UUID) async {
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
            targetLyrics = LyricsService.shared.parseLyrics(yrc: nil, lrc: localLrc, translation: localTrans)
        } else if song.id > 0 {
            if let resp = try? await NetworkManager.shared.lyrics(id: song.id) {
                targetLyrics = LyricsService.shared.parseLyrics(yrc: resp.yrc?.lyric, lrc: resp.lrc?.lyric, translation: resp.tlyric?.lyric)
            }
        }

        guard let item = targetItem else {
            if self.preloadRequestId == requestId {
                self.preloadingTask = nil
            }
            return
        }

        if !Task.isCancelled,
           self.preloadRequestId == requestId,
           self.getNextSong()?.id == song.id,
           self.currentSong?.id != song.id {
            self.preloadedSongId = song.id
            self.preloadedItem = item
            self.preloadedLyrics = targetLyrics
            #if DEBUG
            print("⚡️ [glMusic] 下一首音频与歌词预加载就绪: 《\(song.name)》 (ID: \(song.id))")
            #endif
        }
        if self.preloadRequestId == requestId {
            self.preloadingTask = nil
        }
    }

    func invalidatePreload() {
        if isCrossfading {
            cancelCrossfade()
        }
        preloadRequestId = UUID()
        preloadingTask?.cancel()
        preloadingTask = nil
        preloadedSongId = nil
        preloadedItem = nil
        preloadedLyrics = nil
    }

    // MARK: - Lyrics Loading (Delegated to LyricsService)

    func loadLyrics(for songId: Int, sessionId: UUID? = nil) async {
        // 0. 优先命中预加载歌词
        if preloadedSongId == songId, let lyrics = preloadedLyrics, !lyrics.isEmpty {
            if let sessionId = sessionId, self.currentSessionId != sessionId { return }
            self.lyrics = lyrics
            self.currentLyricIndex = 0
            self.isLoadingLyrics = false
            self.preloadedLyrics = nil
            return
        }

        isLoadingLyrics = true
        lyrics = []
        currentLyricIndex = 0

        let fetched = await LyricsService.shared.fetchLyrics(for: songId)
        if let sessionId = sessionId, self.currentSessionId != sessionId { return }
        self.lyrics = fetched
        self.isLoadingLyrics = false
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
            let wasEmptyOrSingle = playlist.count <= 1
            playlist.append(song)
            // 保护机制：若列表已有 >=2 首歌，追加至末尾绝不影响当前播放曲目与紧邻的下一首，无需中断预加载与淡变
            if wasEmptyOrSingle {
                invalidatePreload()
            }
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
            let nextIndex = currentIndex + 1
            currentIndex = (nextIndex >= 0 && nextIndex < playlist.count) ? nextIndex : 0
        }
        guard playlist.indices.contains(currentIndex) else { return }
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
        let prevIndex = currentIndex - 1
        currentIndex = (prevIndex >= 0 && prevIndex < playlist.count) ? prevIndex : max(0, playlist.count - 1)
        guard playlist.indices.contains(currentIndex) else { return }
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

    // MARK: - Media Center & Now Playing Integration (Delegated to NowPlayingService)

    private func updateNowPlaying() {
        NowPlayingService.shared.update(
            song: currentSong,
            duration: duration,
            currentTime: currentTime,
            isPlaying: isPlaying
        )
    }

    private func fetchArtwork(for song: APISong, sessionId: UUID) {
        // 1. 优先检查本地封面 (已下载歌曲或本地导入歌曲)
        if let localCoverURL = DownloadManager.shared.localCoverURL(for: song.id),
           let nsImage = NSImage(contentsOf: localCoverURL) {
            applyArtwork(nsImage, for: song, sessionId: sessionId)
            return
        }

        // 2. 本地不存在，异步拉取网络封面
        guard let coverUrl = song.coverUrl, let url = URL(string: coverUrl) else {
            if self.currentSessionId == sessionId {
                self.currentBlurredArtwork = nil
            }
            return
        }
        Task { [weak self] in
            guard let (data, _) = try? await URLSession.shared.data(from: url),
                  let nsImage = NSImage(data: data) else { return }
            await MainActor.run { [weak self] in
                guard let self = self, self.currentSessionId == sessionId else { return }
                self.applyArtwork(nsImage, for: song, sessionId: sessionId)
            }
        }
    }

    private func applyArtwork(_ nsImage: NSImage, for song: APISong, sessionId: UUID) {
        guard self.currentSessionId == sessionId else { return }
        NowPlayingService.shared.setArtwork(nsImage)

        // 异步预生成高斯模糊背景小图
        Task.detached(priority: .userInitiated) { [weak self] in
            let blurred = NowPlayingService.generateBlurredArtwork(from: nsImage)
            await MainActor.run { [weak self] in
                guard let self = self, self.currentSessionId == sessionId else { return }
                self.currentBlurredArtwork = blurred
            }
        }
    }

    private func setupRemoteCommands() {
        NowPlayingService.shared.setupRemoteCommands(
            onPlay: { [weak self] in self?.resume() },
            onPause: { [weak self] in self?.pause() },
            onToggle: { [weak self] in self?.togglePlay() },
            onNext: { [weak self] in self?.next() },
            onPrevious: { [weak self] in self?.previous() },
            onSeek: { [weak self] time in self?.seek(to: time) }
        )
    }

    // MARK: - Observers

    private var timeObserverTickCounter: Int = 0

    private func setupTimeObserver() {
        if let existing = timeObserver {
            player.removeTimeObserver(existing)
            timeObserver = nil
        }

        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.1, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            MainActor.assumeIsolated {
                guard let self else { return }
                let t = time.seconds
                guard t.isFinite else { return }

                self.timeObserverTickCounter &+= 1

                // 智能按需分频降耗 (Adaptive Tick Throttling):
                // 仅当开启逐字卡拉OK动效或桌面悬浮歌词时，以全频 10Hz (每 100ms) 响应以保障毫秒级扫光流畅；
                // 普通主界面静置播放、或全屏歌词选择“经典/聚光灯”模式时，无需高频唤醒主线程，
                // 自动智能降频至 ~3.3Hz (每 300ms 刷新一次)，消减 66% 主线程重排与绘制开销。
                let isKaraokeActive = (self.isShowingLyrics && LyricsStyleManager.shared.animationMode == .karaoke) || DesktopLyricsManager.shared.isShowing
                if !isKaraokeActive && (self.timeObserverTickCounter % 3 != 0) {
                    return
                }

                self.currentTime = t
                let sec = Int(t)
                if self.currentSecond != sec {
                    self.currentSecond = sec
                }
                if !self.lyrics.isEmpty {
                    let newIdx = LyricsService.shared.findLyricIndex(at: t, in: self.lyrics, currentIndex: self.currentLyricIndex)
                    if self.currentLyricIndex != newIdx {
                        self.currentLyricIndex = newIdx
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

    private func setupEndObserver() {
        NotificationCenter.default.addObserver(
            forName: AVPlayerItem.didPlayToEndTimeNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            MainActor.assumeIsolated {
                guard let self else { return }

                // 1. 若当前正在进行歌曲末尾平滑交叉渐变 (Crossfade)，下一首已在淡入播放中！
                // 绝不能触发 self.next() 导致下一曲被打断并重新从 0 秒起播！应立即无缝加速完成交接。
                if self.isCrossfading {
                    if self.crossfadingTargetItem != nil {
                        self.completeCrossfadeImmediately()
                        return
                    } else {
                        self.cancelCrossfade()
                    }
                }

                // 2. 仅响应当前正在播放的 item 的结束通知
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
                if currentSong?.id == song.id { isLoading = false }
                return
            }

            guard currentSong?.id == song.id else { return }

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
        crossfadingTargetSong = nextSong
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
                self.crossfadingTargetSong = nil
                self.crossfadingTargetItem = nil
                return
            }

            self.crossfadingTargetItem = incomingItem

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

    private func completeCrossfadeImmediately() {
        guard isCrossfading, let targetSong = crossfadingTargetSong, let targetItem = crossfadingTargetItem else {
            cancelCrossfade()
            return
        }
        crossfadeTask?.cancel()
        crossfadeTask = nil
        fadePlayer.volume = Float(volume)
        player.volume = 0.0
        finishCrossfade(to: targetSong, with: targetItem)
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
        currentSecond = Int(currentTime)
        if let idx = playlist.firstIndex(where: { $0.id == nextSong.id }) {
            currentIndex = idx
        }
        HistoryManager.shared.record(song: nextSong)
        UserDefaults.standard.set(nextSong.id, forKey: "last_played_song_id")
        let sessionId = UUID()
        self.currentSessionId = sessionId
        updateNowPlaying()
        fetchArtwork(for: nextSong, sessionId: sessionId)

        // 歌词平滑接管
        currentLyricIndex = 0
        Task {
            await loadLyrics(for: nextSong.id, sessionId: sessionId)
        }

        isCrossfading = false
        crossfadeTask = nil
        crossfadingTargetSong = nil
        crossfadingTargetItem = nil
        #if DEBUG
        print("✅ [glMusic] 交叉渐变平滑完成，现已无缝过渡至: 《\(nextSong.name)》")
        #endif
    }

    func cancelCrossfade() {
        guard isCrossfading else { return } // 核心防线：未处于交叉渐变期，绝不触发任何破坏性操作与音量突变
        crossfadeTask?.cancel()
        crossfadeTask = nil
        crossfadingTargetSong = nil
        crossfadingTargetItem = nil
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
