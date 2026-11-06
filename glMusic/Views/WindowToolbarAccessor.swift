//
//  WindowToolbarAccessor.swift
//  glMusic
//
//  Created by go love on 11/2/26.
//

import AppKit
import SwiftUI

/// Window Toolbar Accessor: 清除系统默认的 sidebar toggle 按钮，并优化窗口样式与初始键盘焦点
struct WindowToolbarAccessor: NSViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var didClearInitialFocus = false
    }

    func makeNSView(context: Context) -> NSView {
        ThinScrollerConfigurator.shared.configureIfNeeded()
        let view = NSView()
        DispatchQueue.main.async {
            configureWindow(view.window, coordinator: context.coordinator)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            configureWindow(nsView.window, coordinator: context.coordinator)
        }
    }

    private func configureWindow(_ window: NSWindow?, coordinator: Coordinator) {
        guard let window = window else { return }

        window.titlebarAppearsTransparent = true
        window.styleMask.insert(.fullSizeContentView)

        // 从 NSToolbar 中移除任何边栏切换按钮
        if let toolbar = window.toolbar {
            for (index, item) in toolbar.items.enumerated().reversed() {
                let id = item.itemIdentifier.rawValue
                if item.itemIdentifier == .toggleSidebar ||
                   id.contains("toggleSidebar") ||
                   id.contains("sidebarToggle") {
                    toolbar.removeItem(at: index)
                }
            }
        }

        // 查找底层 NSSplitView 与 NSSplitViewController 并固定侧边栏尺寸与禁用拖拽光标
        if let splitView = findSplitView(in: window.contentView) {
            // 1. 将 splitView 动态归类为 LockedSplitView，彻底清除分界线处调整尺寸的光标 (resizeLeftRight) 与拖拽跟踪
            if !(splitView is LockedSplitView) {
                object_setClass(splitView, LockedSplitView.self)
                window.invalidateCursorRects(for: splitView)
            }

            // 2. 锁定 NSSplitViewController 的 sidebarItem 尺寸与禁止折叠
            let splitVC = (splitView.delegate as? NSSplitViewController) ?? findSplitViewController(in: window.contentViewController)
            if let sidebarItem = splitVC?.splitViewItems.first {
                sidebarItem.minimumThickness = 220
                sidebarItem.maximumThickness = 220
                sidebarItem.holdingPriority = .required
                sidebarItem.canCollapse = false
                sidebarItem.canCollapseFromWindowResize = false
            }
        }

        // 启动时避免抢占焦点，但保留正常键盘交互链路
        window.initialFirstResponder = nil
        if !coordinator.didClearInitialFocus {
            coordinator.didClearInitialFocus = true
            DispatchQueue.main.async {
                window.makeFirstResponder(nil)
            }
        }
    }

    private func findSplitView(in view: NSView?) -> NSSplitView? {
        guard let view = view else { return nil }
        if let split = view as? NSSplitView {
            return split
        }
        for child in view.subviews {
            if let found = findSplitView(in: child) {
                return found
            }
        }
        return nil
    }

    private func findSplitViewController(in vc: NSViewController?) -> NSSplitViewController? {
        guard let vc = vc else { return nil }
        if let split = vc as? NSSplitViewController {
            return split
        }
        for child in vc.children {
            if let found = findSplitViewController(in: child) {
                return found
            }
        }
        return nil
    }
}

/// 自定义 NSSplitView 子类：彻底消除分界线处的光标变形 (resizeLeftRight) 与拖动改变宽度行为
private final class LockedSplitView: NSSplitView {
    override func resetCursorRects() {
        // 空实现：不向系统注册任何分栏调整光标，使鼠标在分界线上保持正常箭头指针
    }

    override func cursorUpdate(with event: NSEvent) {
        NSCursor.arrow.set()
    }

    @objc func _cursorOfDividerAtLogicalIndex(_ index: Int) -> NSCursor? {
        return nil
    }

    @objc func _cursorOfDividerAtIndex(_ index: Int, position: Double, dragLimits: Any) -> NSCursor? {
        return nil
    }

    @objc func cursorRectForDividerAtIndex(_ index: Int) -> NSRect {
        return .zero
    }

    @objc func _effectiveFrameForDrawnFrame(_ drawnFrame: NSRect, ofDividerAtIndex index: Int) -> NSRect {
        return .zero
    }

    @objc func _indexOfDividerForLocation(_ location: NSPoint, andReturnFrame frame: UnsafeMutablePointer<NSRect>?) -> Int {
        return NSNotFound
    }

    @objc func _visualIndexOfDividerForLocation(_ location: NSPoint, andReturnFrame frame: UnsafeMutablePointer<NSRect>?) -> Int {
        return NSNotFound
    }
}

/// 全局滚动条样式管理器：将滚动条定制为超细 (4.5pt)、半透淡雅 (0.24 alpha) 的现代 Apple 风格浮动滚动条
final class ThinScrollerConfigurator {
    static let shared = ThinScrollerConfigurator()
    private var didConfigure = false

    func configureIfNeeded() {
        guard !didConfigure else { return }
        didConfigure = true

        // 1. 强制全局 NSScrollView 采用现代 overlay 浮层滚动条样式（不挤压内容版面，浮动显示）
        let sScrollerStyle = NSSelectorFromString("scrollerStyle")
        if let m = class_getInstanceMethod(NSScrollView.self, sScrollerStyle) {
            let block: @convention(block) (AnyObject) -> Int = { _ in
                return NSScroller.Style.overlay.rawValue
            }
            method_setImplementation(m, imp_implementationWithBlock(block))
        }

        // 2. 对 AppKit 底层所有 NSScrollerImp 类进行方法定制，使其细化、淡化
        let classesToPatch = [
            "NSScrollerImp",
            "NSLegacyScrollerImp",
            "NSOverlayScrollerImp",
            "NSRegularLegacyScrollerImp",
            "NSSmallLegacyScrollerImp",
            "NSRegularOverlayScrollerImp",
            "NSSmallOverlayScrollerImp"
        ]

        for name in classesToPatch {
            guard let cls = NSClassFromString(name) else { continue }

            // 宽度/粗细：缩减为 4.5pt 优雅细条
            let sTrackWidth = NSSelectorFromString("trackWidth")
            if let m = class_getInstanceMethod(cls, sTrackWidth) {
                let block: @convention(block) (AnyObject) -> Double = { _ in return 4.5 }
                method_setImplementation(m, imp_implementationWithBlock(block))
            }

            // 悬停/交互时扩展宽度：微扩至 6.0pt
            let sExpanded = NSSelectorFromString("_expandedTrackWidth")
            if let m = class_getInstanceMethod(cls, sExpanded) {
                let block: @convention(block) (AnyObject) -> Double = { _ in return 6.0 }
                method_setImplementation(m, imp_implementationWithBlock(block))
            }

            // 滚动滑块颜色：自动随浅色/深色主题自适应的高透淡雅色（0.24 透明度）
            let sColor = NSSelectorFromString("_effectiveKnobColor")
            if let m = class_getInstanceMethod(cls, sColor) {
                let block: @convention(block) (AnyObject) -> NSColor = { _ in
                    return NSColor.labelColor.withAlphaComponent(0.24)
                }
                method_setImplementation(m, imp_implementationWithBlock(block))
            }

            // 背景轨道透明度：设为 0.0，消除突兀的灰色轨道底框
            let sSetTrackAlpha = NSSelectorFromString("setTrackAlpha:")
            if let m = class_getInstanceMethod(cls, sSetTrackAlpha) {
                let origIMP = method_getImplementation(m)
                typealias SetAlphaFn = @convention(c) (AnyObject, Selector, Double) -> Void
                let block: @convention(block) (AnyObject, Double) -> Void = { obj, _ in
                    let fn = unsafeBitCast(origIMP, to: SetAlphaFn.self)
                    fn(obj, sSetTrackAlpha, 0.0)
                }
                method_setImplementation(m, imp_implementationWithBlock(block))
            }

            // 滑块透明度上限：控制滑块出现时的最大透明度（淡雅半透）
            let sSetAlpha = NSSelectorFromString("setKnobAlpha:")
            if let m = class_getInstanceMethod(cls, sSetAlpha) {
                let origIMP = method_getImplementation(m)
                typealias SetAlphaFn = @convention(c) (AnyObject, Selector, Double) -> Void
                let block: @convention(block) (AnyObject, Double) -> Void = { obj, alpha in
                    let fn = unsafeBitCast(origIMP, to: SetAlphaFn.self)
                    fn(obj, sSetAlpha, alpha * 0.45)
                }
                method_setImplementation(m, imp_implementationWithBlock(block))
            }
        }
    }
}
