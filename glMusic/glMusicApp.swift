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
        }
       
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1100, height: 720)
        .commands {
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
