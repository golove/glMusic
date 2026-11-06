//
//  Sidebar.swift
//  glMusic
//
//  Created by go love on 10/7/26.
//

import SwiftUI

struct Sidebar: View {
    let items = SideBar.items
    @Binding var selection: String?
    @Environment(PlayerManager.self) private var player
    @Environment(ThemeManager.self) private var themeManager
    @State private var userProfile: UserProfile?
    @State private var showLogin = false
    @State private var userPlaylists: [APIPlaylist] = []  // 用户创建的歌单
    @State private var subscribedPlaylists: [APIPlaylist] = []  // 收藏的歌单

    var body: some View {
        VStack(spacing: 0) {
            List(selection: $selection) {
                ForEach(items) { item in
                    if let children = item.children {
                        Section(item.name.localized) {
                            ForEach(children) { child in
                                Label {
                                    Text(child.name.localized)
                                } icon: {
                                    Image(systemName: child.systemImage ?? "circle")
                                        .foregroundStyle(themeManager.accentColor)
                                }
                                .tag(child.id)
                            }
                        }
                    } else {
                        Label {
                            Text(item.name.localized)
                        } icon: {
                            Image(systemName: item.systemImage ?? "circle")
                                .foregroundStyle(themeManager.accentColor)
                        }
                        .tag(item.id)
                    }
                }

                // MARK: - 我创建的歌单
                if !userPlaylists.isEmpty {
                    Section("创建的歌单".localized) {
                        ForEach(userPlaylists) { pl in
                            Label {
                                Text(pl.name)
                                    .lineLimit(1)
                            } icon: {
                                AsyncImage(url: URL(string: pl.displayCover ?? "")) { phase in
                                    switch phase {
                                    case .success(let img):
                                        img.resizable().aspectRatio(contentMode: .fill)
                                    default:
                                        Image(systemName: "music.note.list")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .frame(width: 20, height: 20)
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                            }
                            .tag("playlist_\(pl.id)")
                        }
                    }
                }

                // MARK: - 收藏的歌单
                if !subscribedPlaylists.isEmpty {
                    Section("收藏的歌单".localized) {
                        ForEach(subscribedPlaylists) { pl in
                            Label {
                                Text(pl.name)
                                    .lineLimit(1)
                            } icon: {
                                AsyncImage(url: URL(string: pl.displayCover ?? "")) { phase in
                                    switch phase {
                                    case .success(let img):
                                        img.resizable().aspectRatio(contentMode: .fill)
                                    default:
                                        Image(systemName: "music.note.list")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .frame(width: 20, height: 20)
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                            }
                            .tag("playlist_\(pl.id)")
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                userFooter
            }
        }
        .toolbar(removing: .sidebarToggle)
        .sheet(isPresented: $showLogin) {
            LoginView { profile in
                userProfile = profile
                // 登录成功后立即加载歌单
                Task { await loadUserPlaylists(uid: profile.userId) }
            }
        }
        .task { await checkLoginStatus() }
        .onChange(of: showLogin) {
            if !showLogin {
                Task { await checkLoginStatus() }
            }
        }
    }

    // MARK: - Bottom User Area

    private var userFooter: some View {
        VStack(spacing: 8) {
            Divider()
                .opacity(0.4)
                .padding(.horizontal, -2)

            // 用户信息卡片
            userProfileCard

            // 快捷工具栏（语言与主题并排对称胶囊）
            HStack(spacing: 6) {
                LanguagePickerButton()
                ThemePickerButton()
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 6)
        .padding(.bottom, 10)
        .background(.regularMaterial)
    }

    @ViewBuilder
    private var userProfileCard: some View {
        if let profile = userProfile {
            // 已登录：显示头像 + 昵称 + 网易云标签 + 退出按钮
            HStack(spacing: 8) {
                AsyncImage(url: URL(string: profile.avatarUrl ?? "")) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().aspectRatio(contentMode: .fill)
                    default:
                        Circle().fill(.blue.gradient)
                            .overlay(
                                Text(String((profile.nickname ?? "U").prefix(1)))
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.white)
                            )
                    }
                }
                .frame(width: 30, height: 30)
                .clipShape(Circle())
                .overlay(
                    Circle().stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
                )

                VStack(alignment: .leading, spacing: 1) {
                    Text(profile.nickname ?? "用户".localized)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text("网易云音乐".localized)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                // 退出登录按钮
                Button {
                    NetworkManager.shared.logout()
                    userProfile = nil
                    userPlaylists = []
                    subscribedPlaylists = []
                    player.likedSongIds = []
                } label: {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: 24)
                        .background(Color.primary.opacity(0.04), in: Circle())
                }
                .buttonStyle(.plain)
                .help("退出登录".localized)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
        } else {
            // 未登录：整行卡片式点击登录
            Button {
                showLogin = true
            } label: {
                HStack(spacing: 9) {
                    Circle()
                        .fill(Color.primary.opacity(0.06))
                        .frame(width: 30, height: 30)
                        .overlay(
                            Image(systemName: "person.crop.circle")
                                .font(.system(size: 16))
                                .foregroundStyle(.secondary)
                        )

                    VStack(alignment: .leading, spacing: 1) {
                        Text("登录网易云".localized)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.primary)

                        Text("同步歌单与收藏".localized)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 4)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.primary.opacity(0.03))
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private func checkLoginStatus() async {
        guard NetworkManager.shared.isLoggedIn else {
            userProfile = nil
            userPlaylists = []
            subscribedPlaylists = []
            return
        }
        do {
            if let profile = try await NetworkManager.shared.loginStatus() {
                userProfile = profile
                await loadUserPlaylists(uid: profile.userId)
                if let uid = profile.userId {
                    await player.loadLikedSongs(uid: uid)
                }
            }
        } catch {
            print("检查登录状态失败: \(error)")
        }
    }

    private func loadUserPlaylists(uid: Int?) async {
        guard let uid else { return }
        do {
            let all = try await NetworkManager.shared.userPlaylists(uid: uid, limit: 50)
            // 区分自己创建的和收藏的
            userPlaylists = all.filter { $0.userId == uid }
            subscribedPlaylists = all.filter { $0.userId != uid }
        } catch {
            print("加载用户歌单失败: \(error)")
        }
    }
}

#Preview {
    Sidebar(selection: .constant("home"))
        .environment(ThemeManager.shared)
        .environment(LanguageManager.shared)
}
