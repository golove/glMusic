//
//  glMusicApp.swift
//  glMusic
//
//  Created by go love on 9/25/26.
//

import SwiftUI
import SwiftData

@main
struct glMusicApp: App {
    @State private var playerManager = PlayerManager()
    @State private var themeManager = ThemeManager.shared
    @State private var languageManager = LanguageManager.shared

    init() {
        ThinScrollerConfigurator.shared.configureIfNeeded()
        setupURLCache()
    }

    private func setupURLCache() {
        let memoryCapacity = 64 * 1024 * 1024  // 64 MB RAM 高频图片与封面极速缓存
        let diskCapacity = 300 * 1024 * 1024   // 300 MB 磁盘持久缓存
        let cache = URLCache(
            memoryCapacity: memoryCapacity,
            diskCapacity: diskCapacity,
            diskPath: "glmusic_image_cache"
        )
        URLCache.shared = cache
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(playerManager)
                .environment(themeManager)
                .environment(languageManager)
                .environment(\.locale, languageManager.currentLocale)
                .tint(themeManager.accentColor)
                .environment(\.defaultMinListRowHeight, 36)
                .task {
                    await ensureBasicCookie()
                }
                .onAppear {
                    DesktopLyricsManager.shared.setup(playerManager: playerManager, themeManager: themeManager)
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1280, height: 800)

        MenuBarExtra {
            MenuBarView()
                .environment(playerManager)
                .environment(themeManager)
                .environment(languageManager)
        } label: {
            HStack(spacing: 3) {
                Image(systemName: playerManager.isPlaying ? "waveform" : "music.note")
            }
        }
        .menuBarExtraStyle(.window)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("关于 glMusic".localized) {
                    NSApplication.shared.orderFrontStandardAboutPanel(
                        options: [
                            .applicationName: "glMusic",
                            .credits: NSAttributedString(
                                string: "优雅的原生 macOS 网易云音乐播放器".localized,
                                attributes: [
                                    .font: NSFont.systemFont(ofSize: 11),
                                    .foregroundColor: NSColor.secondaryLabelColor
                                ]
                            )
                        ]
                    )
                }

                Button("检查更新...".localized) {
                    Task {
                        await UpdateManager.shared.checkForUpdates(isUserInitiated: true)
                    }
                }
            }

            CommandGroup(replacing: .newItem) {
                Button("导入本地音乐...".localized) {
                    DownloadManager.shared.openFilePickerToImport()
                }
                .keyboardShortcut("o", modifiers: [.command])
            }

            CommandMenu("控制".localized) {
                Button(playerManager.isPlaying ? "暂停".localized : "播放".localized) {
                    playerManager.togglePlay()
                }
                .keyboardShortcut(.space, modifiers: [])

                Button("下一首".localized) {
                    playerManager.next()
                }
                .keyboardShortcut(.rightArrow, modifiers: [.command])

                Button("上一首".localized) {
                    playerManager.previous()
                }
                .keyboardShortcut(.leftArrow, modifiers: [.command])

                Divider()

                Button("调高音量".localized) {
                    playerManager.volume = min(1.0, playerManager.volume + 0.05)
                }
                .keyboardShortcut(.upArrow, modifiers: [.command])

                Button("调低音量".localized) {
                    playerManager.volume = max(0.0, playerManager.volume - 0.05)
                }
                .keyboardShortcut(.downArrow, modifiers: [.command])

                Divider()

                Button(playerManager.isShuffled ? "关闭随机播放".localized : "开启随机播放".localized) {
                    playerManager.toggleShuffle()
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])

                Button("切换循环模式".localized) {
                    playerManager.cycleRepeat()
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])

                Divider()

                Button(playerManager.isCrossfadeEnabled ? "关闭音频平滑交叉渐变".localized : "开启音频平滑交叉渐变".localized) {
                    playerManager.toggleCrossfade()
                }

                Divider()

                Button(DesktopLyricsManager.shared.isShowing ? "隐藏桌面悬浮歌词".localized : "显示桌面悬浮歌词".localized) {
                    DesktopLyricsManager.shared.toggle()
                }
                .keyboardShortcut("d", modifiers: [.command, .shift])

                Button(DesktopLyricsManager.shared.isLocked ? "解锁桌面歌词".localized : "锁定桌面歌词".localized) {
                    DesktopLyricsManager.shared.toggleLock()
                }
                .keyboardShortcut("l", modifiers: [.command, .shift])
            }

            CommandMenu("主题风格".localized) {
                ForEach(AppTheme.allCases) { theme in
                    Button {
                        themeManager.select(theme)
                    } label: {
                        if themeManager.currentTheme == theme {
                            Text("✓ \(theme.rawValue) (\(theme.englishName))")
                        } else {
                            Text("   \(theme.rawValue) (\(theme.englishName))")
                        }
                    }
                }
            }

            CommandMenu("语言".localized) {
                ForEach(AppLanguage.allCases) { lang in
                    Button {
                        languageManager.select(lang)
                    } label: {
                        if languageManager.currentLanguage == lang {
                            Text("✓ \(lang.displayName)")
                        } else {
                            Text("   \(lang.displayName)")
                        }
                    }
                }
            }
        }
        
    }

    /// 如果未登录，自动注册游客获取基础 Cookie，避免接口 400 错误
    private func ensureBasicCookie() async {
        guard !NetworkManager.shared.isLoggedIn else { return }
        do {
            try await NetworkManager.shared.registerAnonymous()
            print("✅ 游客登录成功，已获取基础 Cookie")
        } catch {
            print("⚠️ 游客登录失败: \(error)（部分接口可能无法正常使用）")
        }
    }
}
