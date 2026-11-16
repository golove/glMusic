//
//  LyricsView.swift
//  glMusic
//
//  Created by go love on 10/26/26.
//

import SwiftUI

struct LyricsView: View {
    @Binding var selection: String?
    @Environment(PlayerManager.self) private var player
    @Environment(ThemeManager.self) private var themeManager
    @Environment(LanguageManager.self) private var languageManager

    init(selection: Binding<String?>? = nil) {
        self._selection = selection ?? .constant(nil)
    }

    var body: some View {
        ZStack {
            // Blurred Artwork Background (严格贴合窗口大小，防止图片撑大窗口)
            LyricsBackgroundArtwork()

            // Main Content: 居中流体双栏布局 (实时平滑自适应任意窗口拉伸缩放，窗口变大封面相应等比例放大)
            GeometryReader { geometry in
                let availableWidth = geometry.size.width
                let availableHeight = geometry.size.height

                // 封面尺寸自适应：窗口变大时封面相应放大 (平滑在 260pt ~ 520pt 间线性延展，同时兼顾高度与宽度黄金比例)
                let maxFromHeight = max(240, availableHeight * 0.46 - 20)
                let maxFromWidth = max(240, availableWidth * 0.30)
                let coverSize: CGFloat = min(max(260, min(maxFromHeight, maxFromWidth)), 520)

                // 右侧歌词栏宽度：保证适宜的排版阅读舒适度，同时自适应窗口宽度平滑延展 (460 ~ 720pt)
                let rightColumnWidth: CGFloat = min(max(460, availableWidth * 0.38), 720)

                // 左右两栏自适应间距 (平滑连续线性过渡 48 ~ 88pt)
                let columnSpacing: CGFloat = min(max(48, availableWidth * 0.05), 88)

                HStack(alignment: .center, spacing: columnSpacing) {
                    LyricsLeftArtSection(selection: $selection, coverSize: coverSize)
                        .frame(width: coverSize, height: availableHeight, alignment: .center)

                    LyricsScrollAreaView()
                        .frame(width: rightColumnWidth, height: availableHeight)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .top) {
            // 顶部常驻导航与控制栏 (左侧返回，右侧播放设备与音量调节，纯净无胶囊，且100%可点击)
            LyricsTopBarView()
        }
        .ignoresSafeArea()
    }
}

// MARK: - Isolated Ambient Mesh Gradient Artwork Background (macOS 15 原生流光流动网格)

private struct LyricsBackgroundArtwork: View {
    @Environment(PlayerManager.self) private var player

    var body: some View {
        AmbientMeshGradientView(
            artwork: player.currentArtwork ?? player.currentBlurredArtwork,
            songId: player.currentSong?.id ?? 0
        )
    }
}

// MARK: - Isolated Top Bar Section (顶部两端常驻控制栏，状态与悬停完全隔离)

private struct LyricsTopBarView: View {
    @Environment(PlayerManager.self) private var player
    @Environment(ThemeManager.self) private var themeManager
    @Environment(LanguageManager.self) private var languageManager
    @State private var isLeftReturnHovered = false
    @State private var isRightControlsHovered = false
    @State private var lastVolume: Double = 0.5

    var body: some View {
        HStack(alignment: .center) {
            topPinnedBar
                .padding(.leading, 74)

            Spacer()

            audioDevicePickerAndVolume
                .padding(.trailing, 28)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .padding(.top, 14)
    }

    private var topPinnedBar: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                player.isShowingLyrics.toggle()
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 14, weight: .bold))
            }
            .padding(8)
            .foregroundStyle(themeManager.accentColor)
            .background(themeManager.tintColor, in: Circle())
            .overlay(Circle().stroke(themeManager.accentColor.opacity(0.3), lineWidth: 1))
            .contentShape(Circle())
        }
        .padding(.horizontal, 6)
        .buttonStyle(.plain)
        .opacity(isLeftReturnHovered ? 1.0 : 0.8)
        .animation(.easeInOut(duration: 0.2), value: isLeftReturnHovered)
        .onHover { isLeftReturnHovered = $0 }
        .keyboardShortcut(.escape, modifiers: [])
        .help("返回 (Esc)".localized)
    }

    private var audioDevicePickerAndVolume: some View {
        @Bindable var p = player
        return HStack(spacing: 12) {
            // 歌词显示样式设置 (字号/对齐/景深/翻译)
            LyricsStyleButton()

            // 选择播放设备 (放到音量调整前面)
            AudioDevicePickerButton(style: .lyrics)

            HStack(spacing: 8) {
                ProgressSlider(
                    value: $p.volume,
                    trackHeight: 6,
                    activeColor: .white,
                    inactiveColor: .white.opacity(0.25)
                )
                .frame(width: 96)

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
                        .foregroundStyle(.white.opacity(0.9))
                        .contentTransition(.symbolEffect(.replace.byLayer))
                        .animation(.smooth(duration: 0.2), value: volumeIcon)
                        .frame(width: 22, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(player.volume == 0 ? "取消静音".localized : "静音".localized)
            }
            .frame(width: 130)
        }
        .contentShape(Rectangle())
        .opacity(isRightControlsHovered ? 1.0 : 0.75)
        .animation(.easeInOut(duration: 0.2), value: isRightControlsHovered)
        .onHover { isRightControlsHovered = $0 }
    }

    private var volumeIcon: String {
        if player.volume == 0    { return "speaker.slash.fill" }
        if player.volume < 0.33  { return "speaker.wave.1.fill" }
        if player.volume < 0.66  { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }
}

// MARK: - Isolated Left Art & Playback Section (独立左侧封面与播控，彻底与右侧歌词滚动解耦)

private struct LyricsLeftArtSection: View {
    @Environment(PlayerManager.self) private var player
    @Environment(ThemeManager.self) private var themeManager
    @Binding var selection: String?
    let coverSize: CGFloat

    var body: some View {
        VStack(spacing: 16) {
            if let song = player.currentSong {
                // 1. 专辑封面 (自适应高保真圆角与阴影，随窗口尺寸平滑等比缩放)
                let coverRadius = min(28, max(16, coverSize * 0.055))
                let shadowRadius = min(32, max(18, coverSize * 0.065))
                let shadowY = min(16, max(8, coverSize * 0.035))

                Group {
                    if let localURL = DownloadManager.shared.localCoverURL(for: song.id),
                       let img = NSImage(contentsOf: localURL) {
                        Image(nsImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        CachedAsyncCoverView(
                            urlString: song.coverUrl,
                            placeholderIcon: "music.note",
                            targetSize: coverSize,
                            cornerRadius: coverRadius,
                            cancelOnDisappear: false,
                            fixedSize: true
                        )
                    }
                }
                .background(Color.clear)
                .frame(width: coverSize, height: coverSize)
                .clipShape(RoundedRectangle(cornerRadius: coverRadius))
                .shadow(color: .black.opacity(0.40), radius: shadowRadius, y: shadowY)

                // 2. 歌曲信息 (标题、艺术家、专辑) - 严格与封面等宽对齐，随封面等比自适应放缩
                let titleFontSize: CGFloat = min(max(20, coverSize * 0.065), 28)
                let artistFontSize: CGFloat = min(max(13, coverSize * 0.038), 16)
                let albumFontSize: CGFloat = min(max(11, coverSize * 0.032), 14)
                let heartIconSize: CGFloat = min(max(18, coverSize * 0.055), 24)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .center, spacing: 8) {
                        Text(song.name)
                            .font(.system(size: titleFontSize, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Spacer()

                        if player.isPersonalFM {
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    player.trashCurrentFMSong()
                                }
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: heartIconSize * 0.9))
                                    .foregroundStyle(.white.opacity(0.65))
                            }
                            .buttonStyle(.plain)
                            .help("不喜欢并从私人 FM 移除（不再推荐）".localized)
                        }

                        Button {
                            player.toggleLike(for: song)
                        } label: {
                            Image(systemName: player.isLiked(song.id) ? "heart.fill" : "heart")
                                .font(.system(size: heartIconSize))
                                .foregroundStyle(player.isLiked(song.id) ? themeManager.accentColor : .white.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                    }

                    ArtistLinksView(
                        artists: song.ar,
                        fallbackText: song.displayArtist,
                        fontSize: artistFontSize,
                        weight: .medium,
                        normalColor: .white.opacity(0.85),
                        hoverColor: .white,
                        separatorColor: .white.opacity(0.5)
                    ) { artistId in
                        navigateToArtist(id: artistId)
                    }

                    if !song.displayAlbum.isEmpty {
                        if let albumId = song.al?.id, albumId > 0 {
                            ArtistClickableLabel(
                                name: song.displayAlbum,
                                fontSize: albumFontSize,
                                weight: .regular,
                                normalColor: .white.opacity(0.55),
                                hoverColor: .white.opacity(0.9)
                            ) {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    player.isShowingLyrics = false
                                }
                                withAnimation(.easeInOut(duration: 0.22)) {
                                    selection = "album_\(albumId)"
                                }
                            }
                        } else {
                            Text(song.displayAlbum)
                                .font(.system(size: albumFontSize))
                                .foregroundStyle(.white.opacity(0.55))
                                .lineLimit(1)
                        }
                    }
                }
                .frame(width: coverSize, alignment: .leading)
                .padding(.top, 4)

                // 2.5 发烧级音质与 Hi-Res 专属徽标 及 心动模式
                HStack(spacing: 8) {
                    AudioQualityBadgeView(compact: false)

                    if player.isPersonalFM {
                        Text("私人 FM".localized)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(themeManager.accentColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(themeManager.accentColor.opacity(0.18), in: Capsule())
                    }

                    Spacer()

                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            player.toggleInfiniteRoaming()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            HeartbeatModeIcon(isActive: player.isInfiniteRoamingEnabled, size: 12)
                            Text("心动模式".localized)
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(player.isInfiniteRoamingEnabled ? themeManager.accentColor : .white.opacity(0.65))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.ultraThinMaterial, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .help(player.isInfiniteRoamingEnabled ? "心动模式 / 无限漫游已开启 (播完后自动接入相似歌曲流)".localized : "开启心动模式 / 相似歌曲无限漫游".localized)
                }
                .frame(width: coverSize, alignment: .leading)
                .padding(.top, 2)

                // 3. 进度条控制 (与封面等宽对齐)
                LyricsProgressSection()
                    .frame(width: coverSize)
                    .padding(.top, 2)

                // 4. 播放控制按键 (均匀分布在封面宽度内，随封面尺寸自适应微放)
                let controlSmallSize: CGFloat = min(max(16, coverSize * 0.046), 21)
                let controlMedSize: CGFloat = min(max(24, coverSize * 0.070), 32)
                let controlPlaySize: CGFloat = min(max(34, coverSize * 0.096), 44)

                HStack {
                    AppleMusicPlaybackButton(
                        systemName: "shuffle",
                        fontSize: controlSmallSize,
                        foregroundStyle: player.isShuffled ? themeManager.accentColor : .white.opacity(0.65),
                        direction: .center
                    ) {
                        player.toggleShuffle()
                    }

                    Spacer()

                    AppleMusicPlaybackButton(
                        systemName: "backward.fill",
                        fontSize: controlMedSize,
                        foregroundStyle: .white,
                        direction: .backward
                    ) {
                        player.previous()
                    }

                    Spacer()

                    AppleMusicPlaybackButton(
                        systemName: player.isPlaying ? "pause.fill" : "play.fill",
                        fontSize: controlPlaySize,
                        foregroundStyle: .white,
                        direction: .center,
                        isMorphing: true
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            player.togglePlay()
                        }
                    }

                    Spacer()

                    AppleMusicPlaybackButton(
                        systemName: "forward.fill",
                        fontSize: controlMedSize,
                        foregroundStyle: .white,
                        direction: .forward
                    ) {
                        player.next()
                    }

                    Spacer()

                    AppleMusicPlaybackButton(
                        systemName: player.repeatMode.systemImage,
                        fontSize: controlSmallSize,
                        foregroundStyle: player.repeatMode.isActive ? themeManager.accentColor : .white.opacity(0.65),
                        direction: .center
                    ) {
                        player.cycleRepeat()
                    }
                }
                .frame(width: coverSize)
                .padding(.top, 4)
            }
        }
        .frame(width: coverSize)
        .frame(maxHeight: .infinity, alignment: .center)
    }

    private func navigateToArtist(id: Int) {
        withAnimation(.easeInOut(duration: 0.25)) {
            player.isShowingLyrics = false
        }
        withAnimation(.easeInOut(duration: 0.22)) {
            selection = "artist_\(id)"
        }
    }
}

// MARK: - Isolated Lyrics Scroll Area (核心歌词滚动容器，独立管理用户滚动/自动对齐/回到播放状态)

private struct LyricsScrollAreaView: View {
    @Environment(PlayerManager.self) private var player
    private var styleManager = LyricsStyleManager.shared
    @State private var isUserScrolling = false
    @State private var isMouseInLyricsArea = false
    @State private var userScrollResumeTask: Task<Void, Never>?
    @State private var lastScrollNotifyTime: TimeInterval = 0
    @State private var scrollMonitor: Any? = nil

    var body: some View {
        GeometryReader { geo in
            let viewportHeight = geo.size.height
            // 垂直居中边距：首行与尾行均能完全居中于屏幕视口正中间 (仿 Apple Music 沉浸式视效)
            let verticalInset = max(80, (viewportHeight - 50) / 2)

            ScrollViewReader { proxy in
                ZStack(alignment: .bottomTrailing) {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(alignment: styleManager.alignment.horizontalAlignment, spacing: styleManager.fontSize.lineSpacing) {
                            if player.isLoadingLyrics {
                                HStack(spacing: 8) {
                                    ProgressView()
                                        .controlSize(.small)
                                    Text("正在加载歌词...".localized)
                                        .font(.system(size: styleManager.fontSize.inactiveFontSize))
                                        .foregroundStyle(.white.opacity(0.6))
                                }
                                .frame(maxWidth: .infinity, minHeight: max(200, viewportHeight * 0.5), alignment: .center)
                            } else if player.lyrics.isEmpty {
                                VStack(spacing: 10) {
                                    Image(systemName: "quote.bubble")
                                        .font(.system(size: 32))
                                        .foregroundStyle(.white.opacity(0.3))
                                    Text("纯音乐，请欣赏".localized)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.6))
                                }
                                .frame(maxWidth: .infinity, minHeight: max(200, viewportHeight * 0.5), alignment: .center)
                            } else {
                                ForEach(Array(player.lyrics.enumerated()), id: \.element.id) { index, line in
                                    let isActive = index == player.currentLyricIndex

                                    LyricLineRowView(
                                        styleManager: styleManager,
                                        line: line,
                                        isActive: isActive,
                                        isUserScrolling: isUserScrolling,
                                        onSeek: {
                                            player.seek(to: line.time)
                                        }
                                    )
                                    .equatable()
                                    .id(line.id)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: styleManager.alignment.frameAlignment)
                        .padding(.top, verticalInset)
                        .padding(.bottom, verticalInset)
                        .padding(.horizontal, 24)
                    }

                    // 悬浮在右下角的“回到正在播放”胶囊按钮（仿 Apple Music 质感）
                    if isUserScrolling {
                        Button {
                            userScrollResumeTask?.cancel()
                            withAnimation(.easeInOut(duration: 0.45)) {
                                isUserScrolling = false
                                scrollToCurrentActive(proxy: proxy)
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.down.to.line.compact")
                                    .font(.system(size: 11, weight: .bold))
                                Text("回到正在播放".localized)
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(.ultraThinMaterial, in: Capsule())
                            .overlay(Capsule().stroke(Color.white.opacity(0.25), lineWidth: 0.8))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.35), radius: 8, y: 4)
                        }
                        .buttonStyle(.plain)
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                        .padding(.bottom, 28)
                        .padding(.trailing, 28)
                    }
                }
                .onHover { inArea in
                    isMouseInLyricsArea = inArea
                }
                .onAppear {
                    scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
                        if isMouseInLyricsArea {
                            notifyUserScrolled(proxy: proxy)
                        }
                        return event
                    }
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(60))
                        if player.lyrics.indices.contains(player.currentLyricIndex) {
                            let activeId = player.lyrics[player.currentLyricIndex].id
                            withAnimation(.easeInOut(duration: 0.35)) {
                                proxy.scrollTo(activeId, anchor: .center)
                            }
                        }
                    }
                }
                .onDisappear {
                    if let monitor = scrollMonitor {
                        NSEvent.removeMonitor(monitor)
                        scrollMonitor = nil
                    }
                    userScrollResumeTask?.cancel()
                }
                .onChange(of: player.currentLyricIndex) {
                    if !isUserScrolling && player.lyrics.indices.contains(player.currentLyricIndex) {
                        let activeId = player.lyrics[player.currentLyricIndex].id
                        withAnimation(.easeInOut(duration: 0.45)) {
                            proxy.scrollTo(activeId, anchor: .center)
                        }
                    }
                }
                .onChange(of: player.currentSong?.id) {
                    isUserScrolling = false
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(80))
                        if player.lyrics.indices.contains(player.currentLyricIndex) {
                            let activeId = player.lyrics[player.currentLyricIndex].id
                            withAnimation(.easeInOut(duration: 0.35)) {
                                proxy.scrollTo(activeId, anchor: .center)
                            }
                        }
                    }
                }
                .onChange(of: player.lyrics.count) {
                    if !isUserScrolling && player.lyrics.indices.contains(player.currentLyricIndex) {
                        let activeId = player.lyrics[player.currentLyricIndex].id
                        withAnimation(.easeInOut(duration: 0.35)) {
                            proxy.scrollTo(activeId, anchor: .center)
                        }
                    }
                }
            }
        }
    }

    private func notifyUserScrolled(proxy: ScrollViewProxy) {
        let now = CACurrentMediaTime()
        guard now - lastScrollNotifyTime > 0.25 else { return }
        lastScrollNotifyTime = now

        if !isUserScrolling {
            withAnimation(.easeInOut(duration: 0.2)) {
                isUserScrolling = true
            }
        }

        userScrollResumeTask?.cancel()
        userScrollResumeTask = Task {
            try? await Task.sleep(for: .seconds(4.0))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.4)) {
                isUserScrolling = false
                scrollToCurrentActive(proxy: proxy)
            }
        }
    }

    private func scrollToCurrentActive(proxy: ScrollViewProxy) {
        guard player.lyrics.indices.contains(player.currentLyricIndex) else { return }
        let activeId = player.lyrics[player.currentLyricIndex].id
        withAnimation(.easeInOut(duration: 0.45)) {
            proxy.scrollTo(activeId, anchor: .center)
        }
    }
}

// MARK: - Isolated Lyrics Progress Section (拆分进度滑块与 1Hz 秒级时间文本，彻底避免高频重绘)

private struct LyricsProgressSection: View {
    var body: some View {
        VStack(spacing: 4) {
            LyricsProgressSliderView()
            LyricsTimeLabelsView()
        }
    }
}

private struct LyricsProgressSliderView: View {
    @Environment(PlayerManager.self) private var player

    var body: some View {
        @Bindable var p = player
        ProgressSlider(
            value: $p.sliderProgress,
            trackHeight: 5,
            activeColor: .white,
            inactiveColor: .white.opacity(0.25),
            commitsOnDragEnd: true,
            onCommit: { fraction in
                p.seek(byProgress: fraction)
            }
        )
    }
}

private struct LyricsTimeLabelsView: View {
    @Environment(PlayerManager.self) private var player

    var body: some View {
        HStack {
            Text(player.currentTimeText)
                .font(.system(size: 10).monospacedDigit())
                .foregroundStyle(.white.opacity(0.6))
            Spacer()
            Text(player.remainingTimeText)
                .font(.system(size: 10).monospacedDigit())
                .foregroundStyle(.white.opacity(0.6))
        }
    }
}

// MARK: - Isolated Lyric Line Row View (消除全列表重复重绘与高斯模糊突发开销，支持 Equatable 快速跳过)

private struct LyricLineRowView: View, Equatable {
    @Environment(ThemeManager.self) private var themeManager
    var styleManager: LyricsStyleManager
    let line: LyricLine
    let isActive: Bool
    let isUserScrolling: Bool
    let onSeek: () -> Void
    @State private var isHovered = false

    static func == (lhs: LyricLineRowView, rhs: LyricLineRowView) -> Bool {
        lhs.line.id == rhs.line.id &&
        lhs.isActive == rhs.isActive &&
        lhs.isUserScrolling == rhs.isUserScrolling &&
        lhs.styleManager.animationMode == rhs.styleManager.animationMode &&
        lhs.styleManager.alignment == rhs.styleManager.alignment &&
        lhs.styleManager.fontSize == rhs.styleManager.fontSize &&
        lhs.styleManager.isTranslationEnabled == rhs.styleManager.isTranslationEnabled &&
        lhs.styleManager.isDepthBlurEnabled == rhs.styleManager.isDepthBlurEnabled
    }

    var body: some View {
        let font = Font.system(
            size: isActive ? styleManager.fontSize.activeFontSize : styleManager.fontSize.inactiveFontSize,
            weight: isActive ? .bold : .medium
        )
        // 景深感知采用平滑对比度衰减 (与 Apple Music 设计一致，0 GPU 卷积滤镜损耗，且仅活跃行变化)
        let depthOpacity: Double = {
            if isActive { return 1.0 }
            if isHovered { return 0.85 }
            return styleManager.isDepthBlurEnabled ? 0.30 : 0.45
        }()

        VStack(alignment: styleManager.alignment.horizontalAlignment, spacing: 4) {
            if isActive && styleManager.animationMode == .karaoke {
                // 仅活跃行独立订阅 currentTime 扫光，99% 普通行 0 CPU 损耗
                ActiveKaraokeLyricLineView(
                    line: line,
                    font: font,
                    textAlignment: styleManager.alignment.textAlignment,
                    inactiveColor: isHovered ? Color.white.opacity(0.85) : Color.white.opacity(depthOpacity)
                )
                .scaleEffect(
                    1.025,
                    anchor: styleManager.alignment == .center ? .center : .leading
                )
            } else {
                Text(line.text)
                    .font(font)
                    .multilineTextAlignment(styleManager.alignment.textAlignment)
                    .foregroundStyle(
                        isActive
                            ? AnyShapeStyle(themeManager.lyricSoftGradient)
                            : AnyShapeStyle(isHovered ? Color.white.opacity(0.85) : Color.white.opacity(depthOpacity))
                    )
                    .scaleEffect(
                        isActive ? 1.02 : 1.0,
                        anchor: styleManager.alignment == .center ? .center : .leading
                    )
            }

            if styleManager.isTranslationEnabled, let trans = line.translation, !trans.isEmpty {
                Text(trans)
                    .font(.system(
                        size: isActive ? styleManager.fontSize.activeTranslationSize : styleManager.fontSize.inactiveTranslationSize,
                        weight: .medium
                    ))
                    .multilineTextAlignment(styleManager.alignment.textAlignment)
                    .foregroundStyle(
                        isActive
                            ? Color.white.opacity(0.85)
                            : (isHovered ? Color.white.opacity(0.65) : Color.white.opacity(depthOpacity * 0.75))
                    )
            }
        }
        .frame(maxWidth: .infinity, alignment: styleManager.alignment.frameAlignment)
        .contentShape(Rectangle())
        .onHover { h in
            if !isUserScrolling && isHovered != h {
                isHovered = h
            }
        }
        .onTapGesture {
            onSeek()
        }
        .padding(.vertical, 2)
    }
}

// MARK: - 仅活跃行独立监听播放进度 (彻底与普通行隔离，消除全列表每 100ms 重绘)

private struct ActiveKaraokeLyricLineView: View {
    @Environment(PlayerManager.self) private var player
    let line: LyricLine
    let font: Font
    let textAlignment: TextAlignment
    let inactiveColor: Color

    var body: some View {
        let offsetSec = LyricsStyleManager.shared.lyricOffsetMs / 1000.0
        let effectiveTime = max(0, player.currentTime - offsetSec)
        let lineProgress = line.progress(at: effectiveTime)
        KaraokeLyricLineView(
            text: line.text,
            isActive: true,
            progress: lineProgress,
            font: font,
            textAlignment: textAlignment,
            inactiveColor: inactiveColor
        )
    }
}

#Preview("歌词布局测试") {
    let player = LyricsPreviewData.makePlayer()

    LyricsView()
        .environment(player)
        .environment(ThemeManager.shared)
        .environment(LanguageManager.shared)
        .frame(width: 1200, height: 760)
}
