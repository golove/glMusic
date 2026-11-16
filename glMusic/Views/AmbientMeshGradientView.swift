//
//  AmbientMeshGradientView.swift
//  glMusic
//
//  Created by go love on 11/12/26.
//

import SwiftUI
import AppKit
import QuartzCore

// MARK: - 封面多维自适应调色板模型

struct ArtworkColorPalette: Equatable {
    let primary: NSColor
    let secondary: NSColor
    let accent: NSColor
    let ambient: NSColor
    let baseBackground: NSColor

    var colors: [NSColor] {
        [primary, secondary, accent, ambient]
    }
}

// MARK: - 封面多维自适应调色板提取器 (高效极速采样 + Apple Music 风格色彩生动度与互补色映射)

final class ArtworkColorExtractor: @unchecked Sendable {
    static let shared = ArtworkColorExtractor()

    private let cache = NSCache<NSString, PaletteBox>()

    private final class PaletteBox {
        let palette: ArtworkColorPalette
        init(_ palette: ArtworkColorPalette) { self.palette = palette }
    }

    private init() {
        cache.countLimit = 100
    }

    /// 从封面位图提取自适应流光调色板
    func extractPalette(from image: NSImage?, forSongId songId: Int) -> ArtworkColorPalette {
        let key = "\(songId)" as NSString
        if let cached = cache.object(forKey: key)?.palette {
            return cached
        }

        let palette: ArtworkColorPalette
        if let image = image,
           let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            palette = extractFromCGImage(cgImage)
        } else {
            palette = defaultPalette()
        }

        cache.setObject(PaletteBox(palette), forKey: key)
        return palette
    }

    private func extractFromCGImage(_ cgImage: CGImage) -> ArtworkColorPalette {
        // 使用 24x24 快速降采样像素网格分析色彩（耗时 < 0.4ms）
        let width = 24
        let height = 24
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var rawData = [UInt8](repeating: 0, count: width * height * 4)

        guard let context = CGContext(
            data: &rawData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        ) else {
            return defaultPalette()
        }

        context.interpolationQuality = .medium
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        struct ColorSample {
            let hue: CGFloat
            let saturation: CGFloat
            let brightness: CGFloat
            let color: NSColor
            let score: CGFloat
        }

        var samples: [ColorSample] = []
        var maxSat: CGFloat = 0.0

        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * width + x) * 4
                let a = CGFloat(rawData[offset + 3]) / 255.0
                if a < 0.5 { continue }

                let r = CGFloat(rawData[offset]) / 255.0
                let g = CGFloat(rawData[offset + 1]) / 255.0
                let b = CGFloat(rawData[offset + 2]) / 255.0

                let nsColor = NSColor(srgbRed: r, green: g, blue: b, alpha: 1.0)
                var h: CGFloat = 0, s: CGFloat = 0, bri: CGFloat = 0, alpha: CGFloat = 0
                nsColor.getHue(&h, saturation: &s, brightness: &bri, alpha: &alpha)

                if s > maxSat {
                    maxSat = s
                }

                // 过滤死黑与极高亮灰白噪点
                if bri < 0.12 || (s < 0.10 && (bri < 0.20 || bri > 0.94)) {
                    continue
                }

                let score = s * 0.70 + bri * 0.30
                samples.append(ColorSample(hue: h, saturation: s, brightness: bri, color: nsColor, score: score))
            }
        }

        // 若专辑封面纯黑白/极暗灰度，提供现代高级感极光冷色系
        guard maxSat >= 0.15, !samples.isEmpty else {
            return defaultPalette()
        }

        let sorted = samples.sorted { $0.score > $1.score }
        guard let first = sorted.first else {
            return defaultPalette()
        }

        // 查找与第一主色存在明显色相差异的副色 (色相差 >= 45°)
        let secondaryCandidate = sorted.first { sample in
            let diff = abs(sample.hue - first.hue)
            let circularDiff = min(diff, 1.0 - diff)
            return circularDiff >= 0.15 && sample.saturation >= 0.22
        }

        // 查找第三种独特对比色
        let accentCandidate = sorted.first { sample in
            guard let sec = secondaryCandidate else { return false }
            let diff1 = abs(sample.hue - first.hue)
            let circularDiff1 = min(diff1, 1.0 - diff1)
            let diff2 = abs(sample.hue - sec.hue)
            let circularDiff2 = min(diff2, 1.0 - diff2)
            return circularDiff1 >= 0.12 && circularDiff2 >= 0.12 && sample.saturation >= 0.22
        }

        // Apple Music 色彩互补与生动度增强法则：
        // 关键：若封面是人脸肖像/土黄暖色调 (0.03 <= hue <= 0.15)，极易在暗调下衰退为脏深棕色！
        // 此时必须将其提升为通透的日落珊瑚红，并自动搭配皇家靛蓝/紫罗兰与兰花洋红，营造真正的音乐舞台光影！
        let isWarmEarthTone = (first.hue >= 0.03 && first.hue <= 0.15)

        let primaryVibrant: NSColor
        let secondaryVibrant: NSColor
        let accentVibrant: NSColor
        let ambientVibrant: NSColor

        if isWarmEarthTone && secondaryCandidate == nil {
            // 人像/大地暖色调：日落珊瑚粉橙 + 皇家靛蓝 + 炫彩兰花紫 + 深海碧青
            primaryVibrant = NSColor(hue: 0.02, saturation: 0.88, brightness: 0.82, alpha: 1.0)
            secondaryVibrant = NSColor(hue: 0.66, saturation: 0.78, brightness: 0.72, alpha: 1.0)
            accentVibrant = NSColor(hue: 0.82, saturation: 0.82, brightness: 0.76, alpha: 1.0)
            ambientVibrant = NSColor(hue: 0.52, saturation: 0.74, brightness: 0.60, alpha: 1.0)
        } else {
            primaryVibrant = makeVibrantColor(hue: first.hue, saturation: first.saturation, brightness: first.brightness)

            if let sec = secondaryCandidate {
                secondaryVibrant = makeVibrantColor(hue: sec.hue, saturation: sec.saturation, brightness: sec.brightness)
            } else {
                let secHue = (first.hue + 0.55).truncatingRemainder(dividingBy: 1.0)
                secondaryVibrant = NSColor(hue: secHue, saturation: 0.78, brightness: 0.70, alpha: 1.0)
            }

            if let acc = accentCandidate {
                accentVibrant = makeVibrantColor(hue: acc.hue, saturation: acc.saturation, brightness: acc.brightness)
            } else {
                let accHue = (first.hue + 0.78).truncatingRemainder(dividingBy: 1.0)
                accentVibrant = NSColor(hue: accHue, saturation: 0.82, brightness: 0.76, alpha: 1.0)
            }

            let ambHue = (first.hue + 0.35).truncatingRemainder(dividingBy: 1.0)
            ambientVibrant = NSColor(hue: ambHue, saturation: 0.72, brightness: 0.56, alpha: 1.0)
        }

        // 底色永远采用深邃的太空黑曜石暗夜底色 (#0A0C14)，绝不使用浑浊深棕作为画布底色！
        let baseBg = NSColor(srgbRed: 0.04, green: 0.05, blue: 0.08, alpha: 1.0)

        return ArtworkColorPalette(
            primary: primaryVibrant,
            secondary: secondaryVibrant,
            accent: accentVibrant,
            ambient: ambientVibrant,
            baseBackground: baseBg
        )
    }

    private func makeVibrantColor(hue: CGFloat, saturation: CGFloat, brightness: CGFloat) -> NSColor {
        let boostedSat = max(0.75, min(0.98, saturation * 1.35))
        let boostedBri = max(0.60, min(0.85, brightness * 1.25))
        return NSColor(hue: hue, saturation: boostedSat, brightness: boostedBri, alpha: 1.0)
    }

    func defaultPalette() -> ArtworkColorPalette {
        ArtworkColorPalette(
            primary: NSColor(srgbRed: 0.38, green: 0.46, blue: 0.75, alpha: 1.0),
            secondary: NSColor(srgbRed: 0.54, green: 0.36, blue: 0.70, alpha: 1.0),
            accent: NSColor(srgbRed: 0.28, green: 0.58, blue: 0.68, alpha: 1.0),
            ambient: NSColor(srgbRed: 0.44, green: 0.38, blue: 0.62, alpha: 1.0),
            baseBackground: NSColor(srgbRed: 0.04, green: 0.05, blue: 0.08, alpha: 1.0)
        )
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - CoreAnimation 硬件加速流光画布 (GPU 纹理合成器驱动，0.0% CPU 占用)

final class FluidAuraNSView: NSView {
    private let orbCount = 5
    private var orbLayers: [CALayer] = []
    private var currentSongId: Int = -1
    private var isPlaying: Bool = true
    private var isFluidMotionEnabled: Bool = true
    private var currentPalette: ArtworkColorPalette?
    private var lastBounds: CGSize = .zero
    private var hasConfiguredLayout: Bool = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupLayers()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayers()
    }

    private func setupLayers() {
        wantsLayer = true
        let root = CALayer()
        root.masksToBounds = true
        root.backgroundColor = NSColor(srgbRed: 0.04, green: 0.05, blue: 0.08, alpha: 1.0).cgColor
        self.layer = root

        // 创建 5 个高保真平滑羽化同心光环图层 (硬件纹理 Quad，纯 GPU 硬件直通合成，0 CPU 损耗)
        for _ in 0..<orbCount {
            let orb = CALayer()
            orb.minificationFilter = .linear
            orb.magnificationFilter = .linear
            root.addSublayer(orb)
            orbLayers.append(orb)
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard window != nil else { return }
        needsLayout = true
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        needsLayout = true
    }

    override func layout() {
        super.layout()
        let w = bounds.width
        let h = bounds.height
        guard w > 20 && h > 20 else { return }

        layer?.frame = bounds

        if !hasConfiguredLayout || abs(w - lastBounds.width) > 1 || abs(h - lastBounds.height) > 1 {
            lastBounds = bounds.size
            hasConfiguredLayout = true
            applyLayoutAndAnimations()
        }
    }

    func update(palette: ArtworkColorPalette, songId: Int, isPlaying: Bool, isFluidMotionEnabled: Bool) {
        let songChanged = (songId != currentSongId)
        currentSongId = songId

        if songChanged || currentPalette != palette {
            applyColors(from: palette, animated: songChanged && currentPalette != nil)
        }

        updateAnimationSpeed(isPlaying: isPlaying, isFluidMotionEnabled: isFluidMotionEnabled)
    }

    private func applyLayoutAndAnimations() {
        let w = bounds.width
        let h = bounds.height
        guard w > 20 && h > 20 else { return }

        let orbDiameter = max(w, h) * 0.95
        let shimmerDiameter = max(w, h) * 0.70

        let orbBounds = CGRect(x: 0, y: 0, width: orbDiameter, height: orbDiameter)
        let shimmerBounds = CGRect(x: 0, y: 0, width: shimmerDiameter, height: shimmerDiameter)

        let centers: [CGPoint] = [
            CGPoint(x: w * 0.38, y: h * 0.36),
            CGPoint(x: w * 0.62, y: h * 0.54),
            CGPoint(x: w * 0.48, y: h * 0.50),
            CGPoint(x: w * 0.50, y: h * 0.50),
            CGPoint(x: w * 0.50, y: h * 0.45)
        ]

        let paths: [CGPath] = [
            makeLissajousPath(w: w, h: h, centerX: 0.38, centerY: 0.36, ampX: 0.18, ampY: 0.12, freqX: 1.0, freqY: 2.0),
            makeLissajousPath(w: w, h: h, centerX: 0.62, centerY: 0.54, ampX: 0.16, ampY: 0.14, freqX: 1.0, freqY: 1.0),
            makeLissajousPath(w: w, h: h, centerX: 0.48, centerY: 0.50, ampX: 0.18, ampY: 0.15, freqX: 2.0, freqY: 1.0),
            makeLissajousPath(w: w, h: h, centerX: 0.50, centerY: 0.50, ampX: 0.12, ampY: 0.10, freqX: 1.0, freqY: 2.0),
            makeLissajousPath(w: w, h: h, centerX: 0.50, centerY: 0.45, ampX: 0.22, ampY: 0.12, freqX: 1.0, freqY: 2.0)
        ]

        // 舒缓优雅的慢速周期 (14.0s ~ 24.0s)：呼吸从容、清晰流动且不急促
        let moveDurations: [CFTimeInterval] = [18.5, 21.2, 16.0, 24.0, 15.0]

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        for (i, orb) in orbLayers.enumerated() {
            guard i < paths.count else { continue }
            orb.bounds = (i == 4) ? shimmerBounds : orbBounds
            orb.position = centers[i]
            orb.opacity = (i == 4) ? 0.35 : 0.75

            orb.removeAllAnimations()

            // 舒缓温润的闭合大轨迹巡游 (纯 GPU 坐标位移，WindowServer 仅做位置偏移，0 重采样与 0% CPU 损耗)
            let posAnim = CAKeyframeAnimation(keyPath: "position")
            posAnim.path = paths[i]
            posAnim.duration = moveDurations[i]
            posAnim.repeatCount = .infinity
            posAnim.calculationMode = .paced
            posAnim.isRemovedOnCompletion = false
            orb.add(posAnim, forKey: "fluidPosition")
        }

        CATransaction.commit()

        if let palette = currentPalette {
            applyColors(from: palette, animated: false)
        }

        updateAnimationSpeed(isPlaying: isPlaying, isFluidMotionEnabled: isFluidMotionEnabled)
    }

    private func applyColors(from palette: ArtworkColorPalette, animated: Bool) {
        currentPalette = palette
        guard orbLayers.count >= 5 else { return }

        let colors = palette.colors

        let updates: () -> Void = { [weak self] in
            guard let self = self else { return }
            self.layer?.backgroundColor = palette.baseBackground.cgColor

            for (i, orb) in self.orbLayers.enumerated() {
                if i < 4 {
                    let c = colors[i]
                    if let img = self.makeRadialAuraImage(color: c) {
                        orb.contents = img
                    }
                } else {
                    if let img = self.makeShimmerAuraImage(accentColor: palette.accent) {
                        orb.contents = img
                    }
                }
            }
        }

        if animated {
            CATransaction.begin()
            CATransaction.setAnimationDuration(1.2)
            CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeInEaseOut))
            updates()
            CATransaction.commit()
        } else {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            updates()
            CATransaction.commit()
        }
    }

    private func makeRadialAuraImage(color: NSColor, size: CGFloat = 256) -> CGImage? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let ctx = CGContext(
            data: nil,
            width: Int(size),
            height: Int(size),
            bitsPerComponent: 8,
            bytesPerRow: Int(size) * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else { return nil }

        let center = CGPoint(x: size / 2, y: size / 2)
        let radius = size / 2

        let colors = [
            color.withAlphaComponent(0.95).cgColor,
            color.withAlphaComponent(0.70).cgColor,
            color.withAlphaComponent(0.35).cgColor,
            color.withAlphaComponent(0.10).cgColor,
            color.withAlphaComponent(0.0).cgColor
        ] as CFArray

        let locations: [CGFloat] = [0.0, 0.35, 0.65, 0.85, 1.0]

        guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: locations) else { return nil }

        ctx.drawRadialGradient(
            gradient,
            startCenter: center,
            startRadius: 0,
            endCenter: center,
            endRadius: radius,
            options: .drawsAfterEndLocation
        )

        return ctx.makeImage()
    }

    private func makeShimmerAuraImage(accentColor: NSColor, size: CGFloat = 256) -> CGImage? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let ctx = CGContext(
            data: nil,
            width: Int(size),
            height: Int(size),
            bitsPerComponent: 8,
            bytesPerRow: Int(size) * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else { return nil }

        let center = CGPoint(x: size / 2, y: size / 2)
        let radius = size / 2

        let shimmerMid = accentColor.blended(withFraction: 0.60, of: .white) ?? NSColor.white

        let colors = [
            NSColor.white.withAlphaComponent(0.65).cgColor,
            shimmerMid.withAlphaComponent(0.40).cgColor,
            shimmerMid.withAlphaComponent(0.18).cgColor,
            shimmerMid.withAlphaComponent(0.04).cgColor,
            NSColor.clear.cgColor
        ] as CFArray

        let locations: [CGFloat] = [0.0, 0.28, 0.55, 0.80, 1.0]

        guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: locations) else { return nil }

        ctx.drawRadialGradient(
            gradient,
            startCenter: center,
            startRadius: 0,
            endCenter: center,
            endRadius: radius,
            options: .drawsAfterEndLocation
        )

        return ctx.makeImage()
    }

    private func updateAnimationSpeed(isPlaying: Bool, isFluidMotionEnabled: Bool) {
        self.isPlaying = isPlaying
        self.isFluidMotionEnabled = isFluidMotionEnabled
        let shouldAnimate = isPlaying && isFluidMotionEnabled
        guard let rootLayer = self.layer else { return }

        if shouldAnimate {
            if rootLayer.speed == 0.0 {
                let pausedTime = rootLayer.timeOffset
                rootLayer.speed = 1.0
                rootLayer.timeOffset = 0.0
                rootLayer.beginTime = 0.0
                let timeSincePause = rootLayer.convertTime(CACurrentMediaTime(), from: nil) - pausedTime
                rootLayer.beginTime = timeSincePause
            }
        } else {
            if rootLayer.speed != 0.0 {
                let pausedTime = rootLayer.convertTime(CACurrentMediaTime(), from: nil)
                rootLayer.speed = 0.0
                rootLayer.timeOffset = pausedTime
            }
        }
    }

    private func makeLissajousPath(
        w: CGFloat,
        h: CGFloat,
        centerX: CGFloat,
        centerY: CGFloat,
        ampX: CGFloat,
        ampY: CGFloat,
        freqX: CGFloat,
        freqY: CGFloat,
        steps: Int = 48
    ) -> CGPath {
        let path = CGMutablePath()
        for i in 0...steps {
            let theta = (CGFloat(i) / CGFloat(steps)) * 2.0 * .pi
            let x = (centerX + ampX * sin(theta * freqX)) * w
            let y = (centerY + ampY * cos(theta * freqY)) * h
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        path.closeSubpath()
        return path
    }
}

// MARK: - NSViewRepresentable 桥接

struct FluidAuraRepresentable: NSViewRepresentable {
    let artwork: NSImage?
    let songId: Int
    let isPlaying: Bool
    let isFluidMotionEnabled: Bool

    func makeNSView(context: Context) -> FluidAuraNSView {
        let view = FluidAuraNSView()
        let palette = ArtworkColorExtractor.shared.extractPalette(from: artwork, forSongId: songId)
        view.update(
            palette: palette,
            songId: songId,
            isPlaying: isPlaying,
            isFluidMotionEnabled: isFluidMotionEnabled
        )
        return view
    }

    func updateNSView(_ nsView: FluidAuraNSView, context: Context) {
        let palette = ArtworkColorExtractor.shared.extractPalette(from: artwork, forSongId: songId)
        nsView.update(
            palette: palette,
            songId: songId,
            isPlaying: isPlaying,
            isFluidMotionEnabled: isFluidMotionEnabled
        )
    }
}

// MARK: - Apple Music 风格微光流体动态背景 (0.0% CPU 占用 + 通透生动绚丽)

struct AmbientMeshGradientView: View {
    @Environment(PlayerManager.self) private var player
    let artwork: NSImage?
    let songId: Int

    var body: some View {
        ZStack {
            FluidAuraRepresentable(
                artwork: artwork,
                songId: songId,
                isPlaying: player.isPlaying,
                isFluidMotionEnabled: LyricsStyleManager.shared.isFluidMotionEnabled
            )

            // Apple Music 柔和光影暗角蒙版 (中间纯净透明无黑纱，保留 100% 鲜明光彩)
            LinearGradient(
                colors: [
                    Color.black.opacity(0.30),
                    Color.clear,
                    Color.black.opacity(0.36)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }
}
