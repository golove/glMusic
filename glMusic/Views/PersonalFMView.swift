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
    @State private var lastVolume: Double = 0.5

    private var volumeIcon: String {
        if player.volume == 0   { return "speaker.slash.fill" }
        if player.volume < 0.33 { return "speaker.wave.1.fill" }
        if player.volume < 0.66 { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }

    var body: some View {
        @Bindable var player = player

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

                            if player.isPersonalFM && player.isPlaying {
                                Image(systemName: "dot.radiowaves.left.and.right")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(themeManager.accentColor)
                            }
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
                        FMVinylRecordView(song: current, isPlaying: player.isPlaying)

                        // 歌曲详情与自包含控制 (因底部播放条已隐藏，此处提供完整掌控)
                        VStack(alignment: .leading, spacing: 18) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(current.name)
                                    .font(.system(size: 26, weight: .bold))
                                    .lineLimit(2)

                                ArtistLinksView(
                                    artists: current.ar,
                                    fallbackText: current.displayArtist,
                                    fontSize: 15,
                                    weight: .medium,
                                    normalColor: .secondary,
                                    hoverColor: .primary
                                ) { artistId in
                                    selection = "artist_\(artistId)"
                                }

                                if !current.displayAlbum.isEmpty {
                                    Text(current.displayAlbum)
                                        .font(.system(size: 13))
                                        .foregroundStyle(.tertiary)
                                }
                            }

                            // 音质规格徽标
                            AudioQualityBadgeView(compact: false)

                            // 歌词预览片段
                            if !player.lyrics.isEmpty && player.currentLyricIndex < player.lyrics.count {
                                Text(player.lyrics[player.currentLyricIndex].text)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(themeManager.accentColor)
                                    .lineLimit(2)
                                    .animation(.smooth(duration: 0.25), value: player.currentLyricIndex)
                                    .frame(maxWidth: 400, alignment: .leading)
                                    .padding(.vertical, 2)
                            }

                            // 播放进度滑块与时间 (完全自包含，无 PlayerBar 时体验一致)
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
                            .frame(maxWidth: 400)

                            // 核心播放与音量控制栏
                            HStack(spacing: 16) {
                                // 垃圾桶（不再推荐）
                                Button {
                                    handleTrash()
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.system(size: 16))
                                        .foregroundStyle(.secondary)
                                        .frame(width: 42, height: 42)
                                        .background(.ultraThinMaterial, in: Circle())
                                        .overlay(Circle().stroke(.white.opacity(0.12), lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                                .help("不喜欢并从私人 FM 移除（不再推荐）".localized)

                                // 上一首 (或回到开头)
                                Button {
                                    player.previous()
                                } label: {
                                    Image(systemName: "backward.fill")
                                        .font(.system(size: 16))
                                        .foregroundStyle(.primary)
                                        .frame(width: 42, height: 42)
                                        .background(.ultraThinMaterial, in: Circle())
                                        .overlay(Circle().stroke(.white.opacity(0.12), lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                                .help("上一首 / 重新播放".localized)

                                // 播放 / 暂停
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

                                // 下一首
                                Button {
                                    player.next()
                                } label: {
                                    Image(systemName: "forward.fill")
                                        .font(.system(size: 18))
                                        .foregroundStyle(.primary)
                                        .frame(width: 44, height: 44)
                                        .background(.ultraThinMaterial, in: Circle())
                                        .overlay(Circle().stroke(.white.opacity(0.12), lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                                .help("下一首".localized)

                                // 红心喜欢
                                Button {
                                    player.toggleLike(for: current)
                                } label: {
                                    Image(systemName: player.isLiked(current.id) ? "heart.fill" : "heart")
                                        .font(.system(size: 18))
                                        .foregroundStyle(player.isLiked(current.id) ? themeManager.accentColor : .secondary)
                                        .frame(width: 42, height: 42)
                                        .background(.ultraThinMaterial, in: Circle())
                                        .overlay(Circle().stroke(.white.opacity(0.12), lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                                .help((player.isLiked(current.id) ? "取消喜欢" : "喜欢这首歌").localized)

                                Spacer().frame(width: 4)

                                // 音量微调
                                HStack(spacing: 6) {
                                    Button {
                                        if player.volume > 0 {
                                            lastVolume = player.volume
                                            player.volume = 0
                                        } else {
                                            player.volume = lastVolume > 0 ? lastVolume : 0.5
                                        }
                                    } label: {
                                        Image(systemName: volumeIcon)
                                            .font(.system(size: 14))
                                            .foregroundStyle(.secondary)
                                            .frame(width: 18)
                                    }
                                    .buttonStyle(.plain)
                                    .help(player.volume == 0 ? "取消静音".localized : "静音".localized)

                                    ProgressSlider(value: $player.volume, trackHeight: 3)
                                        .frame(width: 66)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(.ultraThinMaterial, in: Capsule())
                                .overlay(Capsule().stroke(.white.opacity(0.08), lineWidth: 1))
                            }
                            .padding(.top, 4)
                        }
                        .frame(maxWidth: 420, alignment: .leading)
                    }
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

// MARK: - FMVinylRecordView (硬件加速黑胶唱片，纯 GPU 渲染，0% CPU 占用)

private struct FMVinylRecordView: View {
    let song: APISong
    let isPlaying: Bool
    @State private var coverImage: NSImage?
    @State private var loadTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            // 静态黑胶底层与大弥散投影 (完全独立静态，绝不旋转，WindowServer 零重绘)
            Circle()
                .fill(Color(white: 0.10))
                .frame(width: 260, height: 260)
                .shadow(color: .black.opacity(0.38), radius: 24, y: 12)

            // 旋转黑胶盘面 (通过 CoreAnimation 硬件驱动，零 CPU 开销)
            VinylDiscRepresentable(image: coverImage, isPlaying: isPlaying, size: 260)
                .frame(width: 260, height: 260)
        }
        .onAppear {
            loadCover()
        }
        .onChange(of: song.id) { _, _ in
            loadCover()
        }
        .onDisappear {
            loadTask?.cancel()
            loadTask = nil
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
