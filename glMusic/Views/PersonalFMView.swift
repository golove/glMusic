//
//  PersonalFMView.swift
//  glMusic
//
//  Created by go love on 11/14/26.
//

import SwiftUI
import AppKit

struct PersonalFMView: View {
    @Binding var selection: String?
    @Environment(PlayerManager.self) private var player
    @Environment(ThemeManager.self) private var themeManager

    @State private var showTrashToast = false
    @State private var trashToastText = ""

    var body: some View {
        ZStack {
            // 背景沉浸渐变
            LinearGradient(
                colors: [
                    themeManager.accentColor.opacity(0.18),
                    Color.purple.opacity(0.12),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 32) {
                // 顶部标题栏
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text("私人 FM".localized)
                                .font(.system(size: 28, weight: .bold))

                            FMHeaderWavesView()
                        }

                        Text("根据你的喜好持续探索无限音乐流 · 永不停止".localized)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .padding(.horizontal, 40)
                .padding(.top, 24)

                Spacer()

                if let current = player.currentSong {
                    // 唱片与封面主体 (纯 GPU 硬件渲染动效，0% CPU 开销)
                    HStack(spacing: 48) {
                        FMVinylRecordView(song: current)

                        // 歌曲详情与自包含控制 (高度严格固定锁定，切歌控件 0 移位 0 跳动)
                        VStack(alignment: .leading, spacing: 14) {
                            // 1. 歌曲标题与歌手专辑 (固定 56pt 高度)
                            VStack(alignment: .leading, spacing: 6) {
                                Text(current.name)
                                    .font(.system(size: 26, weight: .bold))
                                    .lineLimit(1)

                                HStack(spacing: 8) {
                                    ArtistLinksView(
                                        artists: current.ar,
                                        fallbackText: current.displayArtist,
                                        fontSize: 14,
                                        weight: .medium,
                                        normalColor: .secondary,
                                        hoverColor: .primary
                                    ) { artistId in
                                        selection = "artist_\(artistId)"
                                    }

                                    if !current.displayAlbum.isEmpty {
                                        Text("·")
                                            .foregroundStyle(.tertiary)
                                        Text(current.displayAlbum)
                                            .font(.system(size: 13))
                                            .foregroundStyle(.tertiary)
                                            .lineLimit(1)
                                    }
                                }
                            }
                            .frame(height: 56, alignment: .leading)

                            // 2. 音质规格徽标 (固定 24pt 高度)
                            AudioQualityBadgeView(compact: false)
                                .frame(height: 24, alignment: .leading)

                            // 3. 歌词预览片段 (固定 24pt 高度，占位保高，杜绝切歌塌陷导致跳动)
                            FMLyricsPreviewView()

                            // 4. 播放进度滑块与时间 (缩减十分之一至 360pt)
                            FMProgressSectionView()
                                .frame(width: 360, height: 34, alignment: .leading)

                            // 5. 核心播放控制栏 (严格 360pt 宽度与上方进度条完全对齐，居中播放三键，两端对齐垃圾桶与红心)
                            HStack(spacing: 0) {
                                // 垃圾桶（不再推荐，与进度条左端严格对齐）
                                Button {
                                    handleTrash()
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.system(size: 16))
                                        .foregroundStyle(.secondary)
                                        .frame(width: 44, height: 44)
                                        .background(.ultraThinMaterial, in: Circle())
                                        .overlay(Circle().stroke(.white.opacity(0.12), lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                                .help("不喜欢并从私人 FM 移除（不再推荐）".localized)

                                Spacer()

                                // 中间播放控制（上一首、播放/暂停、下一首，居于进度条正中央）
                                HStack(spacing: 16) {
                                    // 上一首 (或回到开头)
                                    AppleMusicPlaybackButton(
                                        systemName: "backward.fill",
                                        fontSize: 18,
                                        foregroundStyle: .primary,
                                        direction: .backward,
                                        isCircular: true,
                                        circleSize: 44
                                    ) {
                                        player.previous()
                                    }
                                    .help("上一首 / 重新播放".localized)

                                    // 播放 / 暂停 (独立微视图)
                                    FMPlayPauseButtonView()

                                    // 下一首
                                    AppleMusicPlaybackButton(
                                        systemName: "forward.fill",
                                        fontSize: 18,
                                        foregroundStyle: .primary,
                                        direction: .forward,
                                        isCircular: true,
                                        circleSize: 44
                                    ) {
                                        player.next()
                                    }
                                    .help("下一首".localized)
                                }

                                Spacer()

                                // 红心喜欢 (与进度条右端严格对齐)
                                FMLikeButtonView(song: current)
                            }
                            .frame(width: 360, height: 52, alignment: .leading)
                        }
                        .frame(width: 360, height: 260, alignment: .leading)
                    }
                    .frame(height: 260)
                    .padding(.horizontal, 40)
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "dot.radiowaves.left.and.right")
                            .font(.system(size: 56))
                            .foregroundStyle(themeManager.accentColor)

                        Text("私人 FM".localized)
                            .font(.system(size: 24, weight: .bold))

                        Text("随时随地根据你的音乐口味，为你探索下一首心动旋律".localized)
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)

                        Button {
                            player.startPersonalFM()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "play.fill")
                                Text("立即开启私人 FM".localized)
                            }
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(themeManager.accentColor, in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 8)
                    }
                }

                Spacer()
                Spacer()
            }
        }
        .overlay(alignment: .top) {
            if showTrashToast {
                Text(trashToastText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.black.opacity(0.85), in: Capsule())
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 20)
            }
        }
        .onAppear {
            if !player.isPersonalFM {
                player.startPersonalFM()
            }
        }
    }

    private func handleTrash() {
        if let current = player.currentSong {
            trashToastText = String(format: "已移至垃圾桶，将减少此类推荐".localized, current.name)
        } else {
            trashToastText = "已移至垃圾桶，将减少此类推荐".localized
        }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            showTrashToast = true
        }
        player.trashCurrentFMSong()

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.easeInOut(duration: 0.25)) {
                showTrashToast = false
            }
        }
    }
}

// MARK: - Isolated Subviews for Zero-Invalidation Playback (隔离高频刷新，主视图 0 重排)

private struct FMHeaderWavesView: View {
    @Environment(PlayerManager.self) private var player
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        if player.isPersonalFM && player.isPlaying {
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(themeManager.accentColor)
        }
    }
}

private struct FMLyricsPreviewView: View {
    @Environment(PlayerManager.self) private var player
    @Environment(ThemeManager.self) private var themeManager
    @State private var isHovering = false

    var body: some View {
        Group {
            if !player.lyrics.isEmpty && player.currentLyricIndex < player.lyrics.count {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        player.isShowingLyrics = true
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "quote.bubble.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(themeManager.accentColor.opacity(0.85))

                        Text(player.lyrics[player.currentLyricIndex].text)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(themeManager.accentColor)
                            .lineLimit(1)
                            .underline(isHovering)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .onHover { hov in
                    isHovering = hov
                }
                .help("点击打开歌词页面".localized)
                .animation(.smooth(duration: 0.25), value: player.currentLyricIndex)
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "quote.bubble")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary.opacity(0.35))

                    Text(player.isLoading ? "歌词载入中...".localized : "私人 FM · 随心探索".localized)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary.opacity(0.55))
                        .lineLimit(1)
                }
            }
        }
        .frame(height: 24, alignment: .leading)
        .frame(maxWidth: 360, alignment: .leading)
    }
}

private struct FMProgressSectionView: View {
    @Environment(PlayerManager.self) private var player
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        @Bindable var player = player
        VStack(spacing: 6) {
            ProgressSlider(
                value: $player.sliderProgress,
                trackHeight: 4,
                activeColor: themeManager.accentColor,
                commitsOnDragEnd: true,
                onCommit: { fraction in
                    player.seek(byProgress: fraction)
                }
            )

            HStack {
                Text(player.currentTimeText)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(player.remainingTimeText)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 360)
    }
}

private struct FMPlayPauseButtonView: View {
    @Environment(PlayerManager.self) private var player
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        Button {
            if player.isPersonalFM {
                player.togglePlay()
            } else {
                player.startPersonalFM()
            }
        } label: {
            Image(systemName: (player.isPersonalFM && player.isPlaying) ? "pause.fill" : "play.fill")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(themeManager.accentColor, in: Circle())
                .shadow(color: themeManager.accentColor.opacity(0.4), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
        .help((player.isPlaying ? "暂停" : "播放").localized)
    }
}

private struct FMLikeButtonView: View {
    @Environment(PlayerManager.self) private var player
    @Environment(ThemeManager.self) private var themeManager
    let song: APISong

    var body: some View {
        let isLiked = player.isLiked(song.id)
        Button {
            player.toggleLike(for: song)
        } label: {
            Image(systemName: isLiked ? "heart.fill" : "heart")
                .font(.system(size: 18))
                .foregroundStyle(isLiked ? themeManager.accentColor : .secondary)
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.12), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .help((isLiked ? "取消喜欢" : "喜欢这首歌").localized)
    }
}

// MARK: - FMVinylRecordView (硬件加速黑胶唱片，纯 GPU 渲染，0% CPU 占用)

private struct FMVinylRecordView: View {
    let song: APISong
    @Environment(PlayerManager.self) private var player
    @State private var coverImage: NSImage?
    @State private var loadTask: Task<Void, Never>?
    @State private var isHovering = false

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                player.isShowingLyrics = true
            }
        } label: {
            ZStack {
                // 静态黑胶底层与大弥散投影 (完全独立静态，绝不旋转，WindowServer 零重绘)
                Circle()
                    .fill(Color(white: 0.10))
                    .frame(width: 260, height: 260)
                    .shadow(color: .black.opacity(isHovering ? 0.48 : 0.38), radius: isHovering ? 28 : 24, y: isHovering ? 14 : 12)

                // 旋转黑胶盘面 (通过 CoreAnimation 硬件驱动，零 CPU 开销)
                VinylDiscRepresentable(image: coverImage, isPlaying: player.isPlaying, size: 260)
                    .frame(width: 260, height: 260)
                    .allowsHitTesting(false)

                // 鼠标悬停时的半透明优雅提示遮罩
                if isHovering {
                    Circle()
                        .fill(Color.black.opacity(0.32))
                        .frame(width: 260, height: 260)
                        .overlay {
                            VStack(spacing: 8) {
                                Image(systemName: "arrow.down.left.and.arrow.up.right")
                                    .font(.system(size: 26, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .shadow(color: .black.opacity(0.5), radius: 4)

                                Text("查看歌词".localized)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.white)
                                    .shadow(color: .black.opacity(0.5), radius: 3)
                            }
                        }
                        .transition(.opacity)
                }
            }
            .contentShape(Circle())
            .scaleEffect(isHovering ? 1.025 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isHovering)
        }
        .buttonStyle(.plain)
        .onHover { hov in
            guard isHovering != hov else { return }
            isHovering = hov
            if hov {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
        .help("点击封面查看歌词".localized)
        .onAppear {
            loadCover()
        }
        .onChange(of: song.id) { _, _ in
            loadCover()
        }
        .onDisappear {
            resetCursor()
            loadTask?.cancel()
            loadTask = nil
        }
    }

    private func resetCursor() {
        if isHovering {
            NSCursor.pop()
            isHovering = false
        }
    }

    private func loadCover() {
        loadTask?.cancel()
        let songId = song.id
        let coverUrl = song.coverUrl
        loadTask = Task { @MainActor in
            if let local = DownloadManager.shared.localCoverURL(for: songId) {
                let img = await Task.detached(priority: .userInitiated) { () -> NSImage? in
                    guard let cgThumb = downsample(url: local, maxPixelSize: 280) else { return nil }
                    return NSImage(cgImage: cgThumb, size: CGSize(width: 140, height: 140))
                }.value
                guard !Task.isCancelled, let finalImage = img else { return }
                self.coverImage = finalImage
                return
            }
            if let remote = coverUrl, !remote.isEmpty {
                let img = await ImagePipelineManager.shared.loadImage(for: remote, targetSize: 140)
                guard !Task.isCancelled, let finalImage = img else { return }
                self.coverImage = finalImage
            }
        }
    }
}

// MARK: - VinylDiscRepresentable (AppKit CoreAnimation 硬件加速层，0% CPU 损耗)

private struct VinylDiscRepresentable: NSViewRepresentable {
    let image: NSImage?
    let isPlaying: Bool
    let size: CGFloat

    func makeNSView(context: Context) -> VinylDiscNSView {
        let view = VinylDiscNSView(size: size)
        view.update(image: image, isPlaying: isPlaying)
        return view
    }

    func updateNSView(_ nsView: VinylDiscNSView, context: Context) {
        nsView.update(image: image, isPlaying: isPlaying)
    }
}

private final class VinylDiscNSView: NSView {
    private let rotatingLayer = CALayer()
    private let groovesLayer = CAShapeLayer()
    private let artworkLayer = CALayer()
    private let spindleLayer = CALayer()
    private var isSpinning = false
    private let discSize: CGFloat

    init(size: CGFloat) {
        self.discSize = size
        super.init(frame: NSRect(x: 0, y: 0, width: size, height: size))
        wantsLayer = true
        setupLayers()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayers() {
        guard let rootLayer = self.layer else { return }
        rootLayer.masksToBounds = false

        let scale = NSScreen.main?.backingScaleFactor ?? 2.0

        // 旋转层：中心对齐，基于中心锚点旋转
        rotatingLayer.frame = CGRect(x: 0, y: 0, width: discSize, height: discSize)
        rotatingLayer.position = CGPoint(x: discSize / 2, y: discSize / 2)
        rotatingLayer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        rotatingLayer.contentsScale = scale

        // 1. 黑胶盘面背景
        let discBase = CALayer()
        discBase.frame = rotatingLayer.bounds
        discBase.backgroundColor = NSColor(white: 0.11, alpha: 1.0).cgColor
        discBase.cornerRadius = discSize / 2
        discBase.masksToBounds = true
        discBase.borderColor = NSColor(white: 1.0, alpha: 0.12).cgColor
        discBase.borderWidth = 1
        discBase.contentsScale = scale
        rotatingLayer.addSublayer(discBase)

        // 2. 唱片微反光音轨纹理 (Grooves)
        let path = CGMutablePath()
        path.addEllipse(in: CGRect(x: 25, y: 25, width: discSize - 50, height: discSize - 50))
        path.addEllipse(in: CGRect(x: 45, y: 45, width: discSize - 90, height: discSize - 90))
        groovesLayer.path = path
        groovesLayer.fillColor = nil
        groovesLayer.strokeColor = NSColor(white: 1.0, alpha: 0.045).cgColor
        groovesLayer.lineWidth = 14
        groovesLayer.contentsScale = scale
        rotatingLayer.addSublayer(groovesLayer)

        // 3. 唱片中心封面图片
        let artworkSize: CGFloat = discSize * 0.54
        let artworkOrigin = (discSize - artworkSize) / 2
        artworkLayer.frame = CGRect(x: artworkOrigin, y: artworkOrigin, width: artworkSize, height: artworkSize)
        artworkLayer.cornerRadius = artworkSize / 2
        artworkLayer.masksToBounds = true
        artworkLayer.contentsGravity = .resizeAspectFill
        artworkLayer.borderColor = NSColor(white: 0.0, alpha: 0.45).cgColor
        artworkLayer.borderWidth = 2
        artworkLayer.backgroundColor = NSColor(white: 0.18, alpha: 1.0).cgColor
        artworkLayer.contentsScale = scale
        rotatingLayer.addSublayer(artworkLayer)

        // 4. 中心小转轴孔
        let spindleSize: CGFloat = 24
        let spindleOrigin = (discSize - spindleSize) / 2
        spindleLayer.frame = CGRect(x: spindleOrigin, y: spindleOrigin, width: spindleSize, height: spindleSize)
        spindleLayer.backgroundColor = NSColor(white: 0.08, alpha: 1.0).cgColor
        spindleLayer.cornerRadius = spindleSize / 2
        spindleLayer.borderColor = NSColor(white: 1.0, alpha: 0.22).cgColor
        spindleLayer.borderWidth = 1
        spindleLayer.contentsScale = scale
        rotatingLayer.addSublayer(spindleLayer)

        rootLayer.addSublayer(rotatingLayer)

        // 注册无限平滑旋转动画
        let rotation = CABasicAnimation(keyPath: "transform.rotation.z")
        rotation.fromValue = 0
        rotation.toValue = CGFloat.pi * 2
        rotation.duration = 25
        rotation.repeatCount = .infinity
        rotation.isRemovedOnCompletion = false
        rotatingLayer.add(rotation, forKey: "vinylSpin")

        // 初始速度设为 0 (暂停状态)
        rotatingLayer.speed = 0.0
    }

    func update(image: NSImage?, isPlaying: Bool) {
        if let img = image {
            if let cgImage = img.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                artworkLayer.contents = cgImage
            } else {
                artworkLayer.contents = img
            }
        }

        if isPlaying && !isSpinning {
            // 平滑恢复旋转 (从暂停处的角度继续旋转)
            let pausedTime = rotatingLayer.timeOffset
            rotatingLayer.speed = 1.0
            rotatingLayer.timeOffset = 0.0
            rotatingLayer.beginTime = 0.0
            let timeSincePause = rotatingLayer.convertTime(CACurrentMediaTime(), from: nil) - pausedTime
            rotatingLayer.beginTime = timeSincePause
            isSpinning = true
        } else if !isPlaying && isSpinning {
            // 平滑定格在当前角度
            let pausedTime = rotatingLayer.convertTime(CACurrentMediaTime(), from: nil)
            rotatingLayer.speed = 0.0
            rotatingLayer.timeOffset = pausedTime
            isSpinning = false
        }
    }
}
