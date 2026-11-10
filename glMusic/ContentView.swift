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
    @Environment(ThemeManager.self) private var themeManager
    @Environment(LanguageManager.self) private var languageManager
    @State private var selection: String? = "home"
    @State private var navigationStack: [String] = []
    @State private var isNavigatingBack = false
    @State private var updateManager = UpdateManager.shared

    var body: some View {
        ZStack {
            NavigationSplitView {
                Sidebar(selection: $selection)
                    .toolbar(removing: .sidebarToggle)
                    .navigationSplitViewColumnWidth(220)
            } detail: {
                ZStack {
                    // 主题流光氛围背景 (优雅通透，自适应随主题平滑渐变)
                    contentThemeBackground

                    detailView
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .ignoresSafeArea(.container, edges: .top)
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    // 悬浮胶囊播放栏 (仅在非全屏歌词模式下加载，歌词展开时彻底解除背部播放条监听与重绘)
                    if !player.isShowingLyrics {
                        PlayerBar(selection: $selection)
                            .padding(.horizontal, 130)
                            .padding(.bottom, 16)
                            .zIndex(99)
                    }
                }
            }
           
            .toolbar(removing: .sidebarToggle)
            .containerBackground(.thinMaterial, for: .window)
            .toolbarBackground(.hidden, for: .windowToolbar)
            .opacity(player.isShowingLyrics ? 0 : 1)
            .allowsHitTesting(!player.isShowingLyrics)

            // 全屏动效歌词视图 (Apple Music 风格)
            if player.isShowingLyrics {
                LyricsView(selection: $selection)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .zIndex(100)
            }

            // 全局快捷键处理 (隐藏按钮)
            keyboardShortcuts
        }
        .frame(minWidth: 1280,minHeight: 720)
        .background(WindowToolbarAccessor())
        .animation(.easeInOut(duration: 0.35), value: player.isShowingLyrics)
        .onChange(of: selection) { oldValue, newValue in
            guard !isNavigatingBack else { return }
            if let old = oldValue, old != newValue {
                let topLevelItems: Set<String> = ["home", "daily", "playlistSquare", "browse", "radio", "search", "history", "artists", "albums", "songs", "downloaded"]
                if let new = newValue, topLevelItems.contains(new) && !old.hasPrefix("playlist_") && !old.hasPrefix("album_") && !old.hasPrefix("artist_") && !old.hasPrefix("radio_") {
                    navigationStack.removeAll()
                } else {
                    navigationStack.append(old)
                }
            }
        }
        .sheet(isPresented: $updateManager.showUpdateDialog) {
            UpdateModalView()
        }
        .alert("当前已是最新版本".localized, isPresented: $updateManager.showUpToDateAlert) {
            Button("好".localized, role: .cancel) {}
        } message: {
            Text(String(format: "glMusic v%@ 已经是最新版本。".localized, updateManager.currentVersion))
        }
        .task {
            // 延迟 1.5 秒启动更新检查，避免影响应用启动时的首屏渲染
            try? await Task.sleep(for: .seconds(1.5))
            await updateManager.checkForUpdates(isUserInitiated: false)
        }
    }

    // MARK: - Ambient Theme Background

    private var contentThemeBackground: some View {
        NightBokehBackground()
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
        case "playlistSquare":
            PlaylistSquareView(selection: $selection)
        case "browse":
            BrowseView(selection: $selection)
        case "radio":
            RadioView(selection: $selection)
        case "search":
            SearchView()
        case "history":
            HistoryView(selection: $selection)
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
                if sel.hasPrefix("playlist_custom_") {
                    let id = sel.replacingOccurrences(of: "playlist_custom_", with: "")
                    CustomPlaylistDetailView(playlistId: id, onBack: {
                        goBack()
                    }, onDelete: {
                        goBack()
                    })
                    .id("playlist_custom_\(id)")
                } else if sel.hasPrefix("playlist_"),
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
            Button("返回上一级".localized) { goBack() }
                .keyboardShortcut("[", modifiers: [.command])

            Button("播放/暂停".localized) { player.togglePlay() }
                .keyboardShortcut(.space, modifiers: [])

            Button("上一首".localized) { player.previous() }
                .keyboardShortcut(.leftArrow, modifiers: [.command])

            Button("下一首".localized) { player.next() }
                .keyboardShortcut(.rightArrow, modifiers: [.command])

            Button("调高音量".localized) { player.volume = min(1.0, player.volume + 0.05) }
                .keyboardShortcut(.upArrow, modifiers: [.command])

            Button("调低音量".localized) { player.volume = max(0.0, player.volume - 0.05) }
                .keyboardShortcut(.downArrow, modifiers: [.command])
        }
        .frame(width: 0, height: 0)
        .opacity(0)
    }
}

#Preview {
    ContentView()
        .environment(PlayerManager())
        .environment(ThemeManager.shared)
        .environment(LanguageManager.shared)
}
