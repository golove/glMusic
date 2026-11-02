//
//  ContentView.swift
//  glMusic
//
//  Created by go love on 9/25/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(PlayerManager.self) private var player
    @State private var selection: String? = "home"
    @State private var navigationStack: [String] = []
    @State private var isNavigatingBack = false

    var body: some View {
        ZStack {
            NavigationSplitView {
                Sidebar(selection: $selection)
                    .toolbar(removing: .sidebarToggle)
                    .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 260)
            } detail: {
                ZStack {
                   

                    
                    detailView
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .ignoresSafeArea(.container, edges: .top)
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    // 悬浮胶囊播放栏
                    PlayerBar()
                        .padding(.horizontal, 60)
                        .padding(.bottom, 16)
                        .zIndex(99)
                }
            }
           
            .toolbar(removing: .sidebarToggle)

            .toolbarBackground(.hidden, for: .windowToolbar)
            .containerBackground(.thinMaterial, for: .window)
//            .ignoresSafeArea()

            // 全屏动效歌词视图 (Apple Music 风格)
            if player.isShowingLyrics {
                LyricsView()
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    .zIndex(100)
            }

            // 全局快捷键处理 (隐藏按钮)
            keyboardShortcuts
        }
        .background(WindowToolbarAccessor())
        .onAppear {
            // 确保窗口启动时清除初始第一响应者，防止焦点环/红框直接出现在 PlayerBar 按钮上
            DispatchQueue.main.async {
                NSApp.keyWindow?.makeFirstResponder(nil)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NSApp.keyWindow?.makeFirstResponder(nil)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                NSApp.keyWindow?.makeFirstResponder(nil)
            }
        }
        .animation(.easeInOut(duration: 0.28), value: player.isShowingLyrics)
        .onChange(of: selection) { oldValue, newValue in
            guard !isNavigatingBack else { return }
            if let old = oldValue, old != newValue {
                let topLevelItems: Set<String> = ["home", "daily", "browse", "radio", "search", "recent", "artists", "albums", "songs", "downloaded"]
                if let new = newValue, topLevelItems.contains(new) && !old.hasPrefix("playlist_") && !old.hasPrefix("album_") && !old.hasPrefix("artist_") && !old.hasPrefix("radio_") {
                    navigationStack.removeAll()
                } else {
                    navigationStack.append(old)
                }
            }
        }
    }

    // MARK: - Navigation

    private func goBack() {
        isNavigatingBack = true
        withAnimation(.easeInOut(duration: 0.2)) {
            if let prev = navigationStack.popLast() {
                selection = prev
            } else {
                selection = "home"
            }
        }
        DispatchQueue.main.async {
            isNavigatingBack = false
        }
    }

    // MARK: - Detail Routing

    @ViewBuilder
    private var detailView: some View {
        switch selection {
        case "home":
            HomeView(selection: $selection)
        case "daily":
            DailyRecommendView()
        case "browse":
            BrowseView(selection: $selection)
        case "radio":
            RadioView(selection: $selection)
        case "search":
            SearchView()
        case "recent":
            RecentlyAddedView(selection: $selection)
        case "artists":
            ArtistsView(selection: $selection)
        case "albums":
            AlbumsView(selection: $selection)
        case "songs":
            SongsView()
        case "downloaded":
            DownloadedSongsView()
        default:
            if let sel = selection {
                if sel.hasPrefix("playlist_"),
                   let id = Int(sel.replacingOccurrences(of: "playlist_", with: "")) {
                    PlaylistDetailView(playlistId: id, onBack: {
                        goBack()
                    })
                    .id("playlist_\(id)")
                } else if sel.hasPrefix("album_"),
                          let id = Int(sel.replacingOccurrences(of: "album_", with: "")) {
                    AlbumDetailView(albumId: id, onBack: {
                        goBack()
                    })
                    .id("album_\(id)")
                } else if sel.hasPrefix("artist_"),
                          let id = Int(sel.replacingOccurrences(of: "artist_", with: "")) {
                    ArtistDetailView(artistId: id, selection: $selection, onBack: {
                        goBack()
                    })
                    .id("artist_\(id)")
                } else if sel.hasPrefix("radio_"),
                          let id = Int(sel.replacingOccurrences(of: "radio_", with: "")) {
                    RadioDetailView(radioId: id, onBack: {
                        goBack()
                    })
                    .id("radio_\(id)")
                } else {
                    HomeView(selection: $selection)
                }
            } else {
                HomeView(selection: $selection)
            }
        }
    }

    // MARK: - Keyboard Shortcuts

    private var keyboardShortcuts: some View {
        Group {
            Button("") { player.togglePlay() }
                .keyboardShortcut(.space, modifiers: [])

            Button("") { player.previous() }
                .keyboardShortcut(.leftArrow, modifiers: [.command])

            Button("") { player.next() }
                .keyboardShortcut(.rightArrow, modifiers: [.command])

            Button("") { player.volume = min(1.0, player.volume + 0.05) }
                .keyboardShortcut(.upArrow, modifiers: [.command])

            Button("") { player.volume = max(0.0, player.volume - 0.05) }
                .keyboardShortcut(.downArrow, modifiers: [.command])
        }
        .frame(width: 0, height: 0)
        .opacity(0)
    }
}

// MARK: - Browse View (榜单列表)

struct BrowseView: View {
    @Binding var selection: String?
    @State private var charts: [APIPlaylist] = []
    @State private var isLoading = true

    init(selection: Binding<String?>? = nil) {
        self._selection = selection ?? .constant("browse")
    }

    let columns = [GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 20)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("浏览")
                    .font(.largeTitle.bold())
                    .padding(.horizontal, 24)
                    .padding(.top, 12)

                if isLoading {
                    ProgressView("加载中...")
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else {
                    Text("排行榜")
                        .font(.title2.bold())
                        .padding(.horizontal, 24)

                    LazyVGrid(columns: columns, spacing: 24) {
                        ForEach(charts) { chart in
                            PlaylistCard(playlist: chart) {
                                selection = "playlist_\(chart.id)"
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                }

                Spacer(minLength: 80)
            }
        }
        .task { await loadCharts() }
    }

    private func loadCharts() async {
        isLoading = true
        do {
            charts = try await NetworkManager.shared.toplist()
        } catch {
            print("BrowseView error: \(error)")
        }
        isLoading = false
    }
}



// MARK: - Window Toolbar Accessor (彻底清除系统默认的 sidebar toggle 按钮，并管理初始键盘焦点)

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

#Preview {
    ContentView()
        .environment(PlayerManager())
}
