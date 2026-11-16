//
//  PlayerBar.swift
//  glMusic
//
//  Created by go love on 10/7/26.
//

import SwiftUI
import NeteaseCloudMusicAPI

struct PlayerBar: View {
    @Binding var selection: String?
    @Environment(PlayerManager.self) private var player
    @Environment(ThemeManager.self) private var themeManager
    @Environment(LanguageManager.self) private var languageManager
    @State private var isHovering = false
    @State private var lastVolume: Double = 0.5

    init(selection: Binding<String?>? = nil) {
        self._selection = selection ?? .constant(nil)
    }

    var body: some View {
        HStack(spacing: 0) {
            // MARK: - Left · Playback Controls
            songInfoSection
                .fixedSize(horizontal: true, vertical: false)

            Spacer(minLength: 16)

            // MARK: - Center · Controls + Progress
            controlsSection
                .frame(minWidth: 260, maxWidth: 520)

            Spacer(minLength: 16)

            // MARK: - Right · Volume + Extras
            extrasSection
                .fixedSize(horizontal: true, vertical: false)
        }
        .frame(height: 44)
        .padding(.horizontal, 18)
        .padding(.vertical, 5)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.15), lineWidth: 1))
        .shadow(color: .black.opacity(0.2), radius: 16, y: 6)
        .focusEffectDisabled()
    }

    // MARK: - Song Info (Left)

    private var songInfoSection: some View {
        HStack(spacing: 12) {
            AppleMusicPlaybackButton(
                systemName: "shuffle",
                fontSize: 13,
                foregroundStyle: player.isShuffled ? themeManager.accentColor : .secondary,
                direction: .center
            ) {
                player.toggleShuffle()
            }

            AppleMusicPlaybackButton(
                systemName: "backward.fill",
                fontSize: 20,
                foregroundStyle: .primary,
                direction: .backward
            ) {
                player.previous()
            }

            AppleMusicPlaybackButton(
                systemName: player.isPlaying ? "pause.fill" : "play.fill",
                fontSize: 24,
                foregroundStyle: .primary,
                direction: .center,
                isMorphing: true
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    player.togglePlay()
                }
            }

            AppleMusicPlaybackButton(
                systemName: "forward.fill",
                fontSize: 20,
                foregroundStyle: .primary,
                direction: .forward
            ) {
                player.next()
            }

            AppleMusicPlaybackButton(
                systemName: player.repeatMode.systemImage,
                fontSize: 13,
                foregroundStyle: player.repeatMode.isActive ? themeManager.accentColor : .secondary,
                direction: .center
            ) {
                player.cycleRepeat()
            }
        }
    }

    // MARK: - Controls (Center)

    private var controlsSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            songHeaderView
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 33)

            PlayerProgressSliderView()
                .frame(height: 7)
        }
        .frame(height: 42)
    }

    private var songHeaderView: some View {
        HStack(spacing: 8) {
            if let song = player.currentSong {
                // Album art from API
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        player.isShowingLyrics.toggle()
                    }
                } label: {
                    SongCoverThumbnailView(song: song, size: 34)
                        .frame(width: 34, height: 34)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(content: {
                        if isHovering {
                            Image(systemName: "arrow.down.left.and.arrow.up.right")
                                .font(.system(size: 16))
                                .foregroundStyle(.white)
                                .shadow(radius: 2)
                        }
                    })
                }
                .onHover { h in withAnimation(.easeInOut(duration: 0.15)) { isHovering = h } }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 1) {
                    Text(song.name)
                        .font(.system(size: 12.5, weight: .semibold))
                        .lineLimit(1)
                    ArtistLinksView(
                        artists: song.ar,
                        fallbackText: song.displayArtist,
                        fontSize: 10.5,
                        weight: .regular,
                        normalColor: .secondary,
                        hoverColor: .primary
                    ) { artistId in
                        navigateToArtist(id: artistId)
                    }
                }
                .layoutPriority(1)

                if player.isLoading {
                    ProgressView()
                        .controlSize(.small)
                }

                // MARK: - 发烧级音质与 Hi-Res 专属徽标 (Apple Music 风格)
                AudioQualityBadgeView(compact: true)

                // MARK: - 心动模式 / 无限漫游图标按键 (纯净矢量图标，点击开启/关闭)
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        player.toggleInfiniteRoaming()
                    }
                } label: {
                    HeartbeatModeIcon(isActive: player.isInfiniteRoamingEnabled, size: 15)
                        .foregroundStyle(player.isInfiniteRoamingEnabled ? themeManager.accentColor : .secondary)
                        .frame(width: 20, height: 20)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(player.isInfiniteRoamingEnabled ? "心动模式 / 无限漫游已开启 (播完后自动根据当前风格接入相似歌曲)".localized : "开启心动模式 / 相似歌曲无限漫游".localized)

                Button {
                    player.toggleLike(for: song)
                } label: {
                    Image(systemName: player.isLiked(song.id) ? "heart.fill" : "heart")
                        .font(.system(size: 15))
                        .foregroundStyle(player.isLiked(song.id) ? themeManager.accentColor : .secondary)
                }
                .frame(width: 18, height: 18)
                .buttonStyle(.plain)
                .help((player.isLiked(song.id) ? "取消喜欢" : "喜欢这首歌").localized)

                // 下载此歌曲
                DownloadButton(song: song, iconSize: 15)
                    .frame(width: 18, height: 18)

            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(.quaternary)
                    .frame(width: 34, height: 34)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: 18))
                            .foregroundStyle(.tertiary)
                    )

                VStack(alignment: .leading, spacing: 1) {
                    Text("未在播放".localized)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Extras (Right)

    private var extrasSection: some View {
        @Bindable var player = player

        return HStack(spacing: 10) {
//            Button {
//                withAnimation(.easeInOut(duration: 0.25)) {
//                    player.isShowingLyrics.toggle()
//                }
//            } label: {
//                Image(systemName: player.isShowingLyrics ? "quote.bubble.fill" : "quote.bubble")
//                    .font(.system(size: 13))
//                    .foregroundStyle(player.isShowingLyrics ? .pink : .secondary)
//            }
//            .buttonStyle(.plain)
//            .help("歌词")

            // 桌面悬浮歌词开关与解锁
            Button {
                if DesktopLyricsManager.shared.isShowing && DesktopLyricsManager.shared.isLocked {
                    DesktopLyricsManager.shared.unlock()
                } else {
                    DesktopLyricsManager.shared.toggle()
                }
            } label: {
                Image(systemName: DesktopLyricsManager.shared.isShowing
                      ? (DesktopLyricsManager.shared.isLocked ? "lock.fill" : "text.bubble.fill")
                      : "text.bubble")
                    .font(.system(size: 16))
                    .foregroundStyle(DesktopLyricsManager.shared.isShowing
                                     ? (DesktopLyricsManager.shared.isLocked ? .orange : themeManager.accentColor)
                                     : .secondary)
            }
            .buttonStyle(.plain)
            .help(DesktopLyricsManager.shared.isLocked ? "桌面歌词已锁定，点击直接解锁 (⇧⌘L)".localized : "桌面悬浮歌词 (⇧⌘D)".localized)
            .contextMenu {
                Button {
                    DesktopLyricsManager.shared.toggle()
                } label: {
                    Label(DesktopLyricsManager.shared.isShowing ? "隐藏桌面歌词".localized : "显示桌面歌词".localized,
                          systemImage: DesktopLyricsManager.shared.isShowing ? "eye.slash" : "eye")
                }

                Button {
                    DesktopLyricsManager.shared.toggleSettings()
                } label: {
                    Label("桌面歌词外观设置".localized, systemImage: "paintpalette")
                }

                Button {
                    DesktopLyricsManager.shared.toggleLock()
                } label: {
                    Label(DesktopLyricsManager.shared.isLocked ? "解锁桌面歌词".localized : "锁定桌面歌词".localized,
                          systemImage: DesktopLyricsManager.shared.isLocked ? "lock.open" : "lock")
                }
            }

            Button {
                player.isShowingQueue.toggle()
            } label: {
                Image(systemName: player.isShowingQueue ? "list.bullet.rectangle.fill" : "list.bullet")
                    .font(.system(size: 18))
                    .foregroundStyle(player.isShowingQueue ? themeManager.accentColor : .secondary)
            }
            .buttonStyle(.plain)
            .help("待播清单与播放历史".localized)
            .popover(isPresented: $player.isShowingQueue, arrowEdge: .top) {
                QueueView(selection: $selection)
            }

            // 睡眠定时器
            SleepTimerMenuButton()

            // 选择播放设备 (放到音量调整前面)
            AudioDevicePickerButton(style: .playerBar)

            HStack(spacing: 8) {
                Button {
                    if player.volume > 0 {
                        lastVolume = player.volume
                        player.volume = 0
                    } else {
                        player.volume = lastVolume > 0 ? lastVolume : 0.5
                    }
                } label: {
                    Image(systemName: volumeIcon)
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                        .contentTransition(.symbolEffect(.replace.byLayer))
                        .animation(.smooth(duration: 0.2), value: volumeIcon)
                        .frame(width: 22, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(player.volume == 0 ? "取消静音".localized : "静音".localized)

                ProgressSlider(value: $player.volume, trackHeight: 3)
                    .frame(width: 76)
            }
        }
    }

    private func navigateToArtist(id: Int) {
        withAnimation(.easeInOut(duration: 0.25)) {
            player.isShowingLyrics = false
        }
        withAnimation(.easeInOut(duration: 0.22)) {
            selection = "artist_\(id)"
        }
    }

    private var volumeIcon: String {
        if player.volume == 0    { return "speaker.slash.fill" }
        if player.volume < 0.33  { return "speaker.wave.1.fill" }
        if player.volume < 0.66  { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }
}

// MARK: - Isolated Progress Slider (防止频繁高刷新导致整栏视图重算)

private struct PlayerProgressSliderView: View {
    @Environment(PlayerManager.self) private var player

    var body: some View {
        @Bindable var player = player
        ProgressSlider(
            value: $player.sliderProgress,
            trackHeight: 3,
            interactiveHeight: 7,
            commitsOnDragEnd: true,
            onCommit: { fraction in
                player.seek(byProgress: fraction)
            }
        )
    }
}

// MARK: - Custom Progress Slider

struct ProgressSlider: View {
    @Binding var value: Double
    var trackHeight: Double
    var activeColor: Color? = nil
    var inactiveColor: Color? = nil
    var interactiveHeight: CGFloat = 8
    var commitsOnDragEnd: Bool = false
    var onCommit: ((Double) -> Void)? = nil
    @State private var isHovering = false
    @State private var isDragging = false
    @State private var dragValue: Double = 0

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let displayedValue = isDragging && commitsOnDragEnd ? dragValue : value
            let trackH: CGFloat = (isHovering || isDragging) ? max(trackHeight + 1.5, 4.5) : trackHeight

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(inactiveColor ?? Color.primary.opacity(0.18))
                    .frame(height: trackH)

                Capsule()
                    .fill(activeColor ?? Color.primary.opacity(0.85))
                    .frame(width: w > 0 ? max(0, min(w, w * displayedValue)) : 0, height: trackH)
            }
            .frame(height: geo.size.height, alignment: .center)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        if !isDragging {
                            dragValue = value
                        }
                        isDragging = true
                        if w > 0 {
                            let newValue = min(max(drag.location.x / w, 0), 1)
                            if commitsOnDragEnd {
                                dragValue = newValue
                            } else {
                                value = newValue
                            }
                        }
                    }
                    .onEnded { _ in
                        if commitsOnDragEnd {
                            value = dragValue
                            onCommit?(dragValue)
                        }
                        isDragging = false
                    }
            )
            .onHover { h in withAnimation(.easeInOut(duration: 0.15)) { isHovering = h } }
        }
        .frame(height: interactiveHeight)
    }
}

// MARK: - Sleep Timer Menu Button

struct SleepTimerMenuButton: View {
    @Environment(PlayerManager.self) private var player
    @State private var sleepTimer = SleepTimerManager.shared

    var body: some View {
        Menu {
            Section("睡眠定时器".localized) {
                if sleepTimer.isActive {
                    Button(role: .destructive) {
                        sleepTimer.cancel()
                    } label: {
                        Label(String(format: "%@ (%@)", "关闭定时器".localized, sleepTimer.remainingFormatted), systemImage: "xmark.circle")
                    }

                    Divider()
                }

                Button {
                    sleepTimer.start(option: .minutes(15), player: player)
                } label: {
                    optionLabel(option: .minutes(15), title: "15 分钟".localized)
                }

                Button {
                    sleepTimer.start(option: .minutes(30), player: player)
                } label: {
                    optionLabel(option: .minutes(30), title: "30 分钟".localized)
                }

                Button {
                    sleepTimer.start(option: .minutes(45), player: player)
                } label: {
                    optionLabel(option: .minutes(45), title: "45 分钟".localized)
                }

                Button {
                    sleepTimer.start(option: .minutes(60), player: player)
                } label: {
                    optionLabel(option: .minutes(60), title: "60 分钟".localized)
                }

                Divider()

                Button {
                    sleepTimer.start(option: .endOfSong, player: player)
                } label: {
                    optionLabel(option: .endOfSong, title: "播完当前歌曲停止".localized)
                }
            }
        } label: {
            HStack(spacing: 3) {
                Image(systemName: sleepTimer.isActive ? "moon.zzz.fill" : "moon")
                    .font(.system(size: 14))
                if sleepTimer.isActive {
                    Text(sleepTimer.shortBadgeText)
                        .font(.system(size: 10, weight: .bold).monospacedDigit())
                }
            }
            .foregroundStyle(sleepTimer.isActive ? ThemeManager.shared.accentColor : .secondary)
            .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help(sleepTimer.isActive ? String(format: "%@: %@", "睡眠定时器运行中".localized, sleepTimer.remainingFormatted) : "睡眠定时器".localized)
    }

    @ViewBuilder
    private func optionLabel(option: SleepTimerOption, title: String) -> some View {
        HStack {
            Text(title)
            if sleepTimer.activeOption == option {
                Image(systemName: "checkmark")
            }
        }
    }
}

#Preview {
    PlayerBar()
        .environment(PlayerManager())
        .environment(ThemeManager.shared)
        .frame(width: 800)
}
