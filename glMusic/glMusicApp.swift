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

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(playerManager)
                .environment(themeManager)
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
                Button("导入本地音乐...") {
                    DownloadManager.shared.openFilePickerToImport()
                }
                .keyboardShortcut("o", modifiers: [.command])
            }

            CommandMenu("主题风格") {
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
