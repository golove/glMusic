//
//  WindowToolbarAccessor.swift
//  glMusic
//
//  Created by go love on 11/2/26.
//

import AppKit
import SwiftUI

/// Window Toolbar Accessor: 清除系统默认的 sidebar toggle 按钮，并管理初始键盘焦点
struct WindowToolbarAccessor: NSViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var eventMonitor: Any?
        var didClearInitialFocus = false

        deinit {
            if let monitor = eventMonitor {
                NSEvent.removeMonitor(monitor)
            }
        }
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()

        // 监听鼠标点击：当用户用鼠标点击窗口时，若当前不是在文本框中输入，自动清除焦点环，保持界面干净
        if context.coordinator.eventMonitor == nil {
            context.coordinator.eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { event in
                DispatchQueue.main.async {
                    if let window = NSApp.keyWindow {
                        let isTextInput = (window.firstResponder is NSTextView) || (window.firstResponder is NSTextField)
                        if !isTextInput {
                            window.makeFirstResponder(nil)
                        }
                    }
                }
                return event
            }
        }

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

        // 查找底层 NSSplitViewController 并禁用 sidebar 折叠
        if let splitVC = findSplitViewController(in: window.contentViewController) {
            if let sidebarItem = splitVC.splitViewItems.first {
                sidebarItem.canCollapse = false
                sidebarItem.canCollapseFromWindowResize = false
            }
        }

        // 关键：防止启动时第一个控件（PlayerBar 的随机播放按钮）自动抢占焦点并展示红框/焦点环
        window.initialFirstResponder = nil
        if !coordinator.didClearInitialFocus {
            coordinator.didClearInitialFocus = true
            DispatchQueue.main.async {
                window.makeFirstResponder(nil)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                window.makeFirstResponder(nil)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                window.makeFirstResponder(nil)
            }
        }
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
