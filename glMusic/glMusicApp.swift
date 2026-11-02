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

 
      

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(playerManager)
                .environment(\.defaultMinListRowHeight, 36)
                .task {
                    await ensureBasicCookie()
                }
        }
       
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1100, height: 720)
        
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
