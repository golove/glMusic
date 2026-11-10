//
//  DesktopLyricsManager.swift
//  glMusic
//
//  Created by go love on 11/10/26.
//

import AppKit
import SwiftUI

enum DesktopLyricsBackgroundStyle: String, CaseIterable, Identifiable, Codable {
    case frosted = "frosted"         // 磨砂毛玻璃 (经典)
    case transparent = "transparent" // 完全透明 (极简纯净，仅保留文字阴影)
    case dark = "dark"               // 深邃高对比 (纯黑)
    case light = "light"             // 纯净亮白 (浅色)

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .frosted:     return "磨砂".localized
        case .dark:        return "深黑".localized
        case .light:       return "浅白".localized
        case .transparent: return "全透".localized
        }
    }
}

// MARK: - Safe Non-Loop Panel & HostingView
// 彻底阻断 AppKit Auto Layout 约束更新循环 (彻底消除 Update Constraints in Window pass 崩溃)

final class DesktopLyricsPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    private var isUpdatingConstraints = false

    override func updateConstraintsIfNeeded() {
        guard !isUpdatingConstraints else { return }
        isUpdatingConstraints = true
        super.updateConstraintsIfNeeded()
        isUpdatingConstraints = false
    }

    override func layoutIfNeeded() {
        guard !isUpdatingConstraints else { return }
        isUpdatingConstraints = true
        super.layoutIfNeeded()
        isUpdatingConstraints = false
    }
}

final class DesktopLyricsHostingView<Content: View>: NSHostingView<Content> {
    private var isUpdating = false

    override func updateConstraints() {
        guard !isUpdating else { return }
        isUpdating = true
        super.updateConstraints()
        isUpdating = false
    }

    override func layout() {
        guard !isUpdating else { return }
        isUpdating = true
        super.layout()
        isUpdating = false
    }
}

@MainActor
@Observable
final class DesktopLyricsManager {
    static let shared = DesktopLyricsManager()

    var isShowing: Bool = false {
        didSet {
            UserDefaults.standard.set(isShowing, forKey: "desktop_lyrics_enabled")
            updatePanelVisibility()
        }
    }

    var isLocked: Bool = false {
        didSet {
            UserDefaults.standard.set(isLocked, forKey: "desktop_lyrics_locked")
            updatePanelLockState()
        }
    }

    var fontSize: CGFloat = 22.0 {
        didSet {
            UserDefaults.standard.set(fontSize, forKey: "desktop_lyrics_font_size")
        }
    }

    var showTranslation: Bool = true {
        didSet {
            UserDefaults.standard.set(showTranslation, forKey: "desktop_lyrics_show_translation")
        }
    }

    var backgroundStyle: DesktopLyricsBackgroundStyle = .frosted {
        didSet {
            UserDefaults.standard.set(backgroundStyle.rawValue, forKey: "desktop_lyrics_bg_style")
        }
    }

    var backgroundOpacity: Double = 0.35 {
        didSet {
            UserDefaults.standard.set(backgroundOpacity, forKey: "desktop_lyrics_bg_opacity")
        }
    }

    var windowWidth: CGFloat = 720 {
        didSet {
            UserDefaults.standard.set(Double(windowWidth), forKey: "desktop_lyrics_width")
        }
    }

    var windowHeight: CGFloat = 96 {
        didSet {
            UserDefaults.standard.set(Double(windowHeight), forKey: "desktop_lyrics_height")
        }
    }

    var showUnlockHandle: Bool = false
    var isMouseOverUnlockArea: Bool = false
    var isShowingSettings: Bool = false {
        didSet {
            updateSettingsPanelVisibility()
        }
    }

    var panel: NSPanel?
    private var settingsPanel: NSPanel?
    private var globalMouseMonitor: Any?
    private var localMouseMonitor: Any?
    private var outsideClickGlobalMonitor: Any?
    private var outsideClickLocalMonitor: Any?
    private var lastClosedTimestamp: Date = .distantPast

    private init() {
        self.isShowing = UserDefaults.standard.bool(forKey: "desktop_lyrics_enabled")
        self.isLocked = UserDefaults.standard.bool(forKey: "desktop_lyrics_locked")

        let savedSize = UserDefaults.standard.double(forKey: "desktop_lyrics_font_size")
        if savedSize >= 14 && savedSize <= 40 {
            self.fontSize = CGFloat(savedSize)
        }

        if UserDefaults.standard.object(forKey: "desktop_lyrics_show_translation") != nil {
            self.showTranslation = UserDefaults.standard.bool(forKey: "desktop_lyrics_show_translation")
        }

        if let savedBg = UserDefaults.standard.string(forKey: "desktop_lyrics_bg_style"),
           let style = DesktopLyricsBackgroundStyle(rawValue: savedBg) {
            self.backgroundStyle = style
        }

        let savedOpacity = UserDefaults.standard.double(forKey: "desktop_lyrics_bg_opacity")
        if savedOpacity > 0 || UserDefaults.standard.object(forKey: "desktop_lyrics_bg_opacity") != nil {
            self.backgroundOpacity = max(0.0, min(1.0, savedOpacity))
        }

        let savedW = UserDefaults.standard.double(forKey: "desktop_lyrics_width")
        if savedW >= 480 && savedW <= 1300 {
            self.windowWidth = CGFloat(savedW)
        }

        let savedH = UserDefaults.standard.double(forKey: "desktop_lyrics_height")
        if savedH >= 70 && savedH <= 180 {
            self.windowHeight = CGFloat(savedH)
        }
    }

    func setup(playerManager: PlayerManager, themeManager: ThemeManager) {
        if panel != nil { return }

        let initialWidth = windowWidth
        let initialHeight = windowHeight
        let mainScreen = NSScreen.main ?? NSScreen.screens.first
        let screenFrame = mainScreen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)

        var defaultOriginX = screenFrame.midX - (initialWidth / 2)
        var defaultOriginY = screenFrame.minY + 40

        // 恢复之前持久化的窗口位置
        if let savedFrameStr = UserDefaults.standard.string(forKey: "desktop_lyrics_frame") {
            let savedRect = NSRectFromString(savedFrameStr)
            if savedRect.width > 100 && savedRect.height > 50 {
                defaultOriginX = savedRect.origin.x
                defaultOriginY = savedRect.origin.y
            }
        }

        let panelRect = NSRect(x: defaultOriginX, y: defaultOriginY, width: initialWidth, height: initialHeight)

        let newPanel = DesktopLyricsPanel(
            contentRect: panelRect,
            styleMask: [.borderless, .resizable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        newPanel.level = .floating
        newPanel.isOpaque = false
        newPanel.backgroundColor = .clear
        newPanel.hasShadow = false
        newPanel.minSize = NSSize(width: 400, height: 60)
        newPanel.maxSize = NSSize(width: 1400, height: 240)
        newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        newPanel.isMovableByWindowBackground = true // 开启系统级无缝平滑拖动
        newPanel.ignoresMouseEvents = isLocked

        let rootView = DesktopLyricsView(manager: self)
            .environment(playerManager)
            .environment(themeManager)
            .environment(LanguageManager.shared)

        let hostingView = DesktopLyricsHostingView(rootView: rootView)
        hostingView.frame = NSRect(x: 0, y: 0, width: initialWidth, height: initialHeight)
        hostingView.autoresizingMask = [.width, .height]
        hostingView.sizingOptions = [] // 核心关键：禁止 NSHostingView 向 NSPanel 施加 Auto Layout 最小/最大/固有内容尺寸约束，彻底根治 Update Constraints in Window 崩溃循环
        newPanel.contentView = hostingView

        // 监听系统级窗口移动并保存坐标 (防抖 0.5s，彻底消除拖拽时高频写磁盘卡顿)
        NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification,
            object: newPanel,
            queue: .main
        ) { [weak self] _ in
            self?.debouncedSaveFrame()
        }

        self.panel = newPanel

        if isShowing {
            newPanel.orderFront(nil)
        }

        if isLocked {
            startLockMonitor()
        }
    }

    // MARK: - Actions

    func toggle() {
        isShowing.toggle()
    }

    func lock() {
        isLocked = true
    }

    func unlock() {
        isLocked = false
    }

    func toggleLock() {
        isLocked.toggle()
    }

    func increaseFontSize() {
        fontSize = min(36.0, fontSize + 2.0)
    }

    func decreaseFontSize() {
        fontSize = max(16.0, fontSize - 2.0)
    }

    /// 实时调整面板物理尺寸 (仅在鼠标拖拽中调用，不触发 @Observable 视图重绘与磁盘 I/O，杜绝 AutoLayout 约束循环死锁)
    func liveResizePanel(newWidth: CGFloat, newHeight: CGFloat) {
        guard let panel = panel, !isLocked else { return }
        let clampedW = max(450, min(1400, newWidth))
        let clampedH = max(70, min(200, newHeight))

        var frame = panel.frame
        let deltaH = clampedH - frame.height
        frame.size.width = clampedW
        frame.size.height = clampedH
        frame.origin.y -= deltaH // 调整高度时保持顶部边缘稳定

        panel.setFrame(frame, display: true, animate: false)
    }

    /// 拖拽尺寸调整完成，落地状态与写入持久化
    func finishResize() {
        guard let panel = panel else { return }
        self.windowWidth = panel.frame.width
        self.windowHeight = panel.frame.height
        saveCurrentFrame()
    }

    func resizePanel(newWidth: CGFloat, newHeight: CGFloat) {
        liveResizePanel(newWidth: newWidth, newHeight: newHeight)
        finishResize()
    }

    func setWidth(_ width: CGFloat) {
        guard let panel = panel else { return }
        let clampedW = max(450, min(1400, width))
        var frame = panel.frame
        frame.size.width = clampedW
        panel.setFrame(frame, display: true, animate: false)
        self.windowWidth = clampedW
        saveCurrentFrame()
    }

    private var saveFrameDebounceTimer: Timer?

    func debouncedSaveFrame() {
        saveFrameDebounceTimer?.invalidate()
        saveFrameDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.saveCurrentFrame()
            }
        }
    }

    func saveCurrentFrame() {
        guard let panel = panel else { return }
        UserDefaults.standard.set(NSStringFromRect(panel.frame), forKey: "desktop_lyrics_frame")
    }

    private func updatePanelVisibility() {
        guard let panel = panel else { return }
        if isShowing {
            panel.orderFront(nil)
        } else {
            panel.orderOut(nil)
            closeSettings()
        }
    }

    func toggleSettings() {
        if isShowingSettings {
            closeSettings()
        } else {
            // 防抖：若刚刚因点击外部调色盘关闭，避免重复开启
            if Date().timeIntervalSince(lastClosedTimestamp) < 0.25 {
                return
            }
            isShowingSettings = true
        }
    }

    func closeSettings() {
        lastClosedTimestamp = Date()
        isShowingSettings = false
    }

    func resetPositionAndSize() {
        guard let panel = panel else { return }
        let mainScreen = NSScreen.main ?? NSScreen.screens.first
        let screenFrame = mainScreen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let defaultWidth: CGFloat = 720
        let defaultHeight: CGFloat = 96
        let originX = screenFrame.midX - (defaultWidth / 2)
        let originY = screenFrame.minY + 40
        let newFrame = NSRect(x: originX, y: originY, width: defaultWidth, height: defaultHeight)

        panel.setFrame(newFrame, display: true, animate: true)
        self.windowWidth = defaultWidth
        self.windowHeight = defaultHeight
        self.fontSize = 22.0
        self.backgroundStyle = .frosted
        self.backgroundOpacity = 0.35
        saveCurrentFrame()
        if let sPanel = settingsPanel {
            positionSettingsPanel(sPanel)
        }
    }

    private func updateSettingsPanelVisibility() {
        if isShowingSettings {
            showSettingsPanel()
            startOutsideClickMonitor()
        } else {
            stopOutsideClickMonitor()
            settingsPanel?.orderOut(nil)
        }
    }

    private func startOutsideClickMonitor() {
        stopOutsideClickMonitor()

        // 监听点击外部应用、桌面或 Dock 区域
        outsideClickGlobalMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, self.isShowingSettings, let sPanel = self.settingsPanel else { return }
                let mouseLoc = NSEvent.mouseLocation
                if !sPanel.frame.contains(mouseLoc) {
                    self.closeSettings()
                }
            }
        }

        // 监听点击本应用内其他窗口或面板
        outsideClickLocalMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] event in
            guard let self = self, self.isShowingSettings, let sPanel = self.settingsPanel else { return event }
            let mouseLoc = NSEvent.mouseLocation
            if !sPanel.frame.contains(mouseLoc) {
                self.closeSettings()
            }
            return event
        }
    }

    private func stopOutsideClickMonitor() {
        if let g = outsideClickGlobalMonitor {
            NSEvent.removeMonitor(g)
            outsideClickGlobalMonitor = nil
        }
        if let l = outsideClickLocalMonitor {
            NSEvent.removeMonitor(l)
            outsideClickLocalMonitor = nil
        }
    }

    private func showSettingsPanel() {
        if let existing = settingsPanel {
            positionSettingsPanel(existing)
            existing.orderFront(nil)
            return
        }

        let width: CGFloat = 320
        let height: CGFloat = 345
        let panel = DesktopLyricsPanel(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating + 1
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false

        let contentView = DesktopLyricsSettingsWindowView(manager: self) { [weak self] in
            self?.closeSettings()
        }
        .environment(ThemeManager.shared)
        .environment(LanguageManager.shared)

        let hostingView = DesktopLyricsHostingView(rootView: contentView)
        hostingView.frame = NSRect(x: 0, y: 0, width: width, height: height)
        hostingView.autoresizingMask = [.width, .height]
        hostingView.sizingOptions = []
        panel.contentView = hostingView

        self.settingsPanel = panel
        positionSettingsPanel(panel)
        panel.orderFront(nil)
    }

    private func positionSettingsPanel(_ panel: NSPanel) {
        let width = panel.frame.width
        let height = panel.frame.height
        let screen = NSScreen.main ?? NSScreen.screens.first
        let sFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)

        var posX = sFrame.midX - (width / 2)
        var posY = sFrame.midY - (height / 2)

        if let lyricsPanel = self.panel {
            let lFrame = lyricsPanel.frame
            posX = max(sFrame.minX + 16, min(sFrame.maxX - width - 16, lFrame.midX - (width / 2)))
            // 优先置于桌面歌词上方，若上方屏幕空间不足则置于下方
            if lFrame.maxY + height + 16 < sFrame.maxY {
                posY = lFrame.maxY + 10
            } else {
                posY = max(sFrame.minY + 16, lFrame.minY - height - 10)
            }
        }

        panel.setFrameOrigin(NSPoint(x: posX, y: posY))
    }

    private func updatePanelLockState() {
        guard let panel = panel else { return }
        panel.ignoresMouseEvents = isLocked

        if isLocked {
            startLockMonitor()
        } else {
            stopLockMonitor()
            showUnlockHandle = false
            isMouseOverUnlockArea = false
        }
    }

    // MARK: - Smart Lock & Unlock Monitor

    private func startLockMonitor() {
        stopLockMonitor()

        var lastMoveCheckTime: TimeInterval = 0
        let handleMouseMove: (NSEvent) -> Void = { [weak self] _ in
            let now = CACurrentMediaTime()
            guard now - lastMoveCheckTime > 0.05 else { return }
            lastMoveCheckTime = now

            Task { @MainActor [weak self] in
                guard let self = self, self.isLocked, let panel = self.panel else { return }
                let mouseLoc = NSEvent.mouseLocation
                let frame = panel.frame

                guard frame.contains(mouseLoc) else {
                    if self.showUnlockHandle {
                        self.showUnlockHandle = false
                    }
                    if self.isMouseOverUnlockArea {
                        self.isMouseOverUnlockArea = false
                        panel.ignoresMouseEvents = true
                    }
                    return
                }

                // 鼠标移入歌词面板区域，显现右上角解锁手柄
                if !self.showUnlockHandle {
                    self.showUnlockHandle = true
                }

                // 右上角解锁按钮热区 (100x46 pt)
                let unlockHotspot = CGRect(
                    x: frame.maxX - 100,
                    y: frame.maxY - 46,
                    width: 100,
                    height: 46
                )

                if unlockHotspot.contains(mouseLoc) {
                    if !self.isMouseOverUnlockArea {
                        self.isMouseOverUnlockArea = true
                        panel.ignoresMouseEvents = false // 激活解锁按钮点击
                    }
                } else {
                    if self.isMouseOverUnlockArea {
                        self.isMouseOverUnlockArea = false
                        panel.ignoresMouseEvents = true // 其余主体歌词区域保持完全穿透
                    }
                }
            }
        }

        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved], handler: handleMouseMove)
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) { event in
            handleMouseMove(event)
            return event
        }
    }

    private func stopLockMonitor() {
        if let g = globalMouseMonitor {
            NSEvent.removeMonitor(g)
            globalMouseMonitor = nil
        }
        if let l = localMouseMonitor {
            NSEvent.removeMonitor(l)
            localMouseMonitor = nil
        }
    }
}
