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

#Preview {
    ContentView()
        .environment(PlayerManager())
}
