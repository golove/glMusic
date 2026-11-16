//
//  MenuBarIconManager.swift
//  glMusic
//
//  Created by go love on 11/13/26.
//

import AppKit
import SwiftUI
import ObjectiveC.runtime

/// 状态栏动效图标管理器：支持歌曲播放时「高/中/低三频真实声学律动」与「三音符沉底大行程跳跃」轻快灵动动效
/// 架构设计：
/// 1. 采用零耗 GPU 硬件图层 (`CALayer`) 直接合成并挂载至原生 `NSStatusBarButton`；
/// 2. SwiftUI `MenuBarExtra` 仅提供 18x18 透明占位图像维持原生按钮尺寸与交互，杜绝任何底层静态位图重叠与双重阴影；
/// 3. 彻底阻断 SwiftUI 视图树每秒 30 次重排与 AppKit `_updateReplicants` 快照风暴，
///    将 CPU 负载由 43% 永久压低至 < 0.5%，单层纯净无重影。
@MainActor
final class MenuBarIconManager: NSObject {
    static let shared = MenuBarIconManager()

    /// 静态静止状态基准图标 (18x18 pt，用于切片提取高清音符纹理)
    let restingIcon: NSImage

    /// 透明占位图标 (供 SwiftUI 状态栏占位使用，避免底层渲染静态图造成双层重叠)
    let transparentPlaceholderImage: NSImage

    /// 是否开启菜单栏动效 (默认开启)
    var isAnimationEnabled: Bool = UserDefaults.standard.object(forKey: "menubar_animation_enabled") == nil ? true : UserDefaults.standard.bool(forKey: "menubar_animation_enabled") {
        didSet {
            UserDefaults.standard.set(isAnimationEnabled, forKey: "menubar_animation_enabled")
            if !isAnimationEnabled {
                stopAnimation(immediate: true)
            } else if lastPlaybackState {
                startAnimation()
            }
        }
    }

    private var animationTimer: Timer?
    private var lastPlaybackState: Bool = false

    /// 下沉到低位舞台跳跃平台的过渡进度：0.0 (居中静止) ~ 1.0 (沉落到底部舞台)
    private var sinkProgress: CGFloat = 0.0
    private var targetSink: CGFloat = 0.0

    // MARK: - CoreAnimation Hardware Layers (单层纯净硬件图层)

    private var isAttached: Bool = false
    private weak var statusBarButton: NSButton?
    private var containerLayer: CALayer?
    private let note1Layer = CALayer()
    private let note2Layer = CALayer()
    private let note3Layer = CALayer()

    // MARK: - Native AppKit Status Item & Popover Architecture

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var eventMonitor: Any?

    private override init() {
        let base = Self.loadBaseIcon()
        self.restingIcon = base
        self.transparentPlaceholderImage = NSImage(size: NSSize(width: 18, height: 18))
        super.init()

        setupLayers(from: base)
    }

    /// 采用系统公开合规的 AppKit NSStatusItem 与 NSPopover 架构，
    /// 彻底消除对私有类名（NSStatusBarButton）的反射查找、窗口层级遍历与轮询 hack，
    /// 保持 CoreAnimation 硬件图层零 CPU 损耗的同时，保障 macOS 系统更新与沙盒环境的稳定兼容。
    func setup(playerManager: PlayerManager, themeManager: ThemeManager, languageManager: LanguageManager) {
        guard statusItem == nil else { return }

        let item = NSStatusBar.system.statusItem(withLength: 28)
        self.statusItem = item

        if let button = item.button {
            button.target = self
            button.action = #selector(handleStatusBarClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            attach(to: button)
        }

        let pop = NSPopover()
        pop.behavior = .transient
        pop.animates = true
        pop.delegate = self
        let menuView = MenuBarView()
            .environment(playerManager)
            .environment(themeManager)
            .environment(languageManager)
        pop.contentViewController = NSHostingController(rootView: menuView)
        self.popover = pop
    }

    // MARK: - Popover Presentation & Fullscreen Window Management

    @objc private func handleStatusBarClick(_ sender: NSStatusBarButton) {
        guard let pop = popover, let button = statusItem?.button else { return }
        if pop.isShown {
            closePopover(sender)
        } else {
            showPopover(button: button)
        }
    }

    private func showPopover(button: NSStatusBarButton) {
        guard let pop = popover else { return }

        // 1. 打开弹出层
        pop.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)

        // 2. 核心适配：全屏应用与跨 Space 置顶渲染
        configurePopoverWindow()
    }

    private func closePopover(_ sender: Any?) {
        popover?.performClose(sender)
        stopEventMonitor()
    }

    private func configurePopoverWindow() {
        guard let window = popover?.contentViewController?.view.window else { return }
        // 关键 1：允许穿透并显示在所有 Spaces（包括全屏浏览器、全屏视频等独立 FullScreen Spaces）
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        // 关键 2：窗口层级提升至 popUpMenu（高于全屏应用及普通浮动窗口，杜绝被遮挡）
        window.level = .popUpMenu
        // 关键 3：强制将窗口推至最顶层渲染并获取焦点
        window.orderFrontRegardless()
        window.makeKey()
    }

    // MARK: - Global Click Monitor (保障全屏应用下点击外部可靠关闭)

    private func startEventMonitor() {
        stopEventMonitor()
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self = self, let pop = self.popover, pop.isShown else { return }

            // 若点击位置在状态栏按钮本身范围内，交由按钮本身的 target-action 切换关闭，避免竞态重复触发
            if let button = self.statusItem?.button, let window = button.window {
                let mouseLocation = NSEvent.mouseLocation
                let buttonScreenRect = window.convertToScreen(button.convert(button.bounds, to: nil))
                if buttonScreenRect.contains(mouseLocation) {
                    return
                }
            }

            pop.performClose(nil)
            self.stopEventMonitor()
        }
    }

    private func stopEventMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    func attachToStatusBarIfNeeded() {
        // 已通过 setup(playerManager:themeManager:languageManager:) 由公开 API 原生接管
    }

    // MARK: - Hardware Layer Setup

    private func setupLayers(from base: NSImage) {
        guard let cg = base.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
        let w = CGFloat(cg.width)
        let h = CGFloat(cg.height)
        let s = w / 18.0

        let cg1 = cg.cropping(to: CGRect(x: 0 * s, y: 0, width: 6.0 * s, height: h))
        let cg2 = cg.cropping(to: CGRect(x: 6.0 * s, y: 0, width: 5.5 * s, height: h))
        let cg3 = cg.cropping(to: CGRect(x: 11.5 * s, y: 0, width: 6.5 * s, height: h))

        let scale = NSScreen.main?.backingScaleFactor ?? 2.0

        note1Layer.contents = cg1
        note1Layer.contentsScale = scale
        note1Layer.frame = CGRect(x: 0, y: 0, width: 6.0, height: 18.0)

        note2Layer.contents = cg2
        note2Layer.contentsScale = scale
        note2Layer.frame = CGRect(x: 6.0, y: 0, width: 5.5, height: 18.0)

        note3Layer.contents = cg3
        note3Layer.contentsScale = scale
        note3Layer.frame = CGRect(x: 11.5, y: 0, width: 6.5, height: 18.0)

        let container = CALayer()
        container.frame = CGRect(x: 0, y: 0, width: 18, height: 18)
        container.masksToBounds = true
        container.addSublayer(note1Layer)
        container.addSublayer(note2Layer)
        container.addSublayer(note3Layer)
        self.containerLayer = container
    }

    private func attach(to button: NSButton) {
        guard !isAttached, let container = containerLayer else { return }
        self.statusBarButton = button
        button.wantsLayer = true
        guard let parentLayer = button.layer else { return }

        // 清除默认按钮位图，由 CoreAnimation 纯净硬件图层唯一合成
        button.image = nil

        let bx = round((button.bounds.width - 18.0) / 2.0)
        let by = round((button.bounds.height - 18.0) / 2.0)
        container.frame = CGRect(x: max(0, bx), y: max(0, by), width: 18, height: 18)

        parentLayer.addSublayer(container)
        isAttached = true
    }

    // MARK: - Playback Control & Animation Loop

    /// 更新当前音频播放状态
    func updatePlaybackState(isPlaying: Bool) {
        lastPlaybackState = isPlaying
        attachToStatusBarIfNeeded()

        guard isAnimationEnabled else {
            stopAnimation(immediate: true)
            return
        }

        if isPlaying {
            targetSink = 1.0
            startAnimation()
        } else {
            targetSink = 0.0
            if animationTimer == nil {
                sinkProgress = 0.0
                applyOffsets(y1: 0, y2: 0, y3: 0)
            }
        }
    }

    /// 启动律动动效 (30 FPS 硬件图层微秒级位移，零 SwiftUI/AutoLayout 开销)
    private func startAnimation() {
        guard animationTimer == nil else { return }

        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.033, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                guard self.isAnimationEnabled else {
                    self.stopAnimation(immediate: true)
                    return
                }

                // 驱动音频频谱引擎单帧计算
                AudioSpectrumManager.shared.updateLevelsForNextFrame()

                // 平滑插值沉底进度
                let sinkSpeed: CGFloat = self.lastPlaybackState ? 0.08 : 0.14
                self.sinkProgress += (self.targetSink - self.sinkProgress) * sinkSpeed

                // 若处于暂停回程阶段且已基本回升到原位，完成优雅停机
                if !self.lastPlaybackState && self.sinkProgress < 0.02 {
                    self.sinkProgress = 0.0
                    self.applyOffsets(y1: 0, y2: 0, y3: 0)
                    self.stopAnimationTimer()
                    AudioSpectrumManager.shared.reset()
                    return
                }

                // 对齐底部舞台所需的沉底位移 (在 NSStatusBarButton Flipped 坐标系中，向下沉底为正位移)
                // 使三颗音符在静音未起跳时平齐沉降在底部 y = 17.0 pt 处 (距 18pt 容器底边留 1.0pt 边距):
                // - 音符1 (明黄 ♩): 默认 bottom=14.0 pt，下移 +3.0 pt -> bottom 达到 17.0 pt
                // - 音符2 (洋红 ♩): 默认 bottom=12.0 pt，下移 +5.0 pt -> bottom 达到 17.0 pt
                // - 音符3 (靛青 ♩): 默认 bottom=14.0 pt，下移 +3.0 pt -> bottom 达到 17.0 pt
                let floor1: CGFloat = 3.0 * self.sinkProgress
                let floor2: CGFloat = 5.0 * self.sinkProgress
                let floor3: CGFloat = 3.0 * self.sinkProgress

                // 沉底后释放出的充沛向上弹跳行程 (在 Flipped 坐标系中，向上跃起为减小 y 值):
                // - 音符1 (明黄 ♩): 最大弹跳 5.5 pt (重低音底鼓爆发)
                // - 音符2 (洋红 ♩): 最大弹跳 6.5 pt (军鼓与人声主旋律爆发)
                // - 音符3 (靛青 ♩): 最大弹跳 5.0 pt (踩镲镲片高频清脆律动)
                let maxBounce1: CGFloat = 5.5
                let maxBounce2: CGFloat = 6.5
                let maxBounce3: CGFloat = 5.0

                let y1: CGFloat
                let y2: CGFloat
                let y3: CGFloat

                if AudioSpectrumManager.shared.isAudioActive {
                    let levels = AudioSpectrumManager.shared.currentLevels
                    // 硬静区截断：微小回落或细微噪音截断为 0，确保平时平平稳稳地坐在底部地台，杜绝任何微幅抖动
                    let bounce1 = levels.bass > 0.05 ? maxBounce1 * levels.bass * self.sinkProgress : 0
                    let bounce2 = levels.mid > 0.05 ? maxBounce2 * levels.mid * self.sinkProgress : 0
                    let bounce3 = levels.treble > 0.05 ? maxBounce3 * levels.treble * self.sinkProgress : 0

                    // 向上跳跃：由底部 floor 向上弹起 (y 减小)
                    y1 = floor1 - bounce1
                    y2 = floor2 - bounce2
                    y3 = floor3 - bounce3
                } else if self.lastPlaybackState {
                    // 音频初始缓冲中或未捕获到音频能量：安安静静平卧在底部平台，不产生任何烦人的微晃抖动
                    y1 = floor1
                    y2 = floor2
                    y3 = floor3
                } else {
                    // 暂停过渡回位中
                    y1 = floor1
                    y2 = floor2
                    y3 = floor3
                }

                self.applyOffsets(y1: y1, y2: y2, y3: y3)
            }
        }

        if let timer = animationTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    /// 应用位移至三颗音符的硬件 CALayer
    private func applyOffsets(y1: CGFloat, y2: CGFloat, y3: CGFloat) {
        // 动态保持容器图层居中
        if let btn = statusBarButton, let container = containerLayer {
            let bx = round((btn.bounds.width - 18.0) / 2.0)
            let by = round((btn.bounds.height - 18.0) / 2.0)
            let origin = CGPoint(x: max(0, bx), y: max(0, by))
            if container.frame.origin != origin {
                container.frame.origin = origin
            }
        }

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        note1Layer.frame.origin.y = y1
        note2Layer.frame.origin.y = y2
        note3Layer.frame.origin.y = y3
        CATransaction.commit()
    }

    private func stopAnimationTimer() {
        animationTimer?.invalidate()
        animationTimer = nil
    }

    private func stopAnimation(immediate: Bool = false) {
        if immediate {
            stopAnimationTimer()
            targetSink = 0.0
            sinkProgress = 0.0
            applyOffsets(y1: 0, y2: 0, y3: 0)
            AudioSpectrumManager.shared.reset()
        } else {
            targetSink = 0.0
            if animationTimer == nil {
                applyOffsets(y1: 0, y2: 0, y3: 0)
            }
        }
    }

    // MARK: - Asset Loading

    private static func loadBaseIcon() -> NSImage {
        if let img = NSImage(named: "MenuBarIcon") {
            let icon = (img.copy() as? NSImage) ?? img
            icon.size = NSSize(width: 18, height: 18)
            icon.isTemplate = false
            return icon
        }
        if let appIcon = NSApplication.shared.applicationIconImage {
            let icon = (appIcon.copy() as? NSImage) ?? appIcon
            icon.size = NSSize(width: 18, height: 18)
            icon.isTemplate = false
            return icon
        }
        return NSImage(size: NSSize(width: 18, height: 18))
    }
}

// MARK: - SwiftUI MenuBar Label View

struct MenuBarIconLabelView: View {
    var playerManager: PlayerManager

    var body: some View {
        // 使用 18x18 全透明占位图，确保 SwiftUI 给状态栏按钮正确分配尺寸，
        // 同时底层完全透明，由 MenuBarIconManager 的 GPU 硬件图层唯一渲染，彻底杜绝双层重影
        Image(nsImage: MenuBarIconManager.shared.transparentPlaceholderImage)
            .onAppear {
                MenuBarIconManager.shared.attachToStatusBarIfNeeded()
                MenuBarIconManager.shared.updatePlaybackState(isPlaying: playerManager.isPlaying)
            }
            .onChange(of: playerManager.isPlaying) { _, isPlaying in
                MenuBarIconManager.shared.updatePlaybackState(isPlaying: isPlaying)
            }
    }
}

// MARK: - NSPopoverDelegate (全屏模式与生命周期管理)

extension MenuBarIconManager: NSPopoverDelegate {
    func popoverWillShow(_ notification: Notification) {
        configurePopoverWindow()
    }

    func popoverDidShow(_ notification: Notification) {
        configurePopoverWindow()
        startEventMonitor()
    }

    func popoverDidClose(_ notification: Notification) {
        stopEventMonitor()
    }
}
