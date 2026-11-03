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
                        Section(item.name) {
                            ForEach(children) { child in
                                Label {
                                    Text(child.name)
                                } icon: {
                                    Image(systemName: child.systemImage ?? "circle")
                                        .foregroundStyle(themeManager.accentColor)
                                }
                                .tag(child.id)
                            }
                        }
                    } else {
                        Label {
                            Text(item.name)
                        } icon: {
                            Image(systemName: item.systemImage ?? "circle")
                                .foregroundStyle(themeManager.accentColor)
                        }
                        .tag(item.id)
                    }
                }

                // MARK: - 我创建的歌单
                if !userPlaylists.isEmpty {
                    Section("创建的歌单") {
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
                    Section("收藏的歌单") {
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
        HStack(spacing: 10) {
            if let profile = userProfile {
                // 已登录：显示头像 + 昵称
                AsyncImage(url: URL(string: profile.avatarUrl ?? "")) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().aspectRatio(contentMode: .fill)
                    default:
                        Circle().fill(.blue.gradient)
                            .overlay(
                                Text(String((profile.nickname ?? "U").prefix(1)))
                                    .font(.caption.bold())
                                    .foregroundStyle(.white)
                            )
                    }
                }
                .frame(width: 32, height: 32)
                .clipShape(Circle())

                Text(profile.nickname ?? "用户")
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                ThemePickerButton()

                // 退出按钮
                Button {
                    NetworkManager.shared.logout()
                    userProfile = nil
                    userPlaylists = []
                    subscribedPlaylists = []
                    player.likedSongIds = []
                } label: {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("退出登录")
            } else {
                // 未登录：显示登录按钮
                Button {
                    showLogin = true
                } label: {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(.quaternary)
                            .frame(width: 32, height: 32)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.secondary)
                            )
                        Text("登录网易云")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "qrcode")
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)

                ThemePickerButton()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial)
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
}
