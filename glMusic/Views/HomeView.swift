//
//  HomeView.swift
//  glMusic
//
//  Created by go love on 10/7/26.
//

import SwiftUI

struct HomeView: View {
    @Binding var selection: String?
    @Environment(PlayerManager.self) private var player
    @Environment(ThemeManager.self) private var themeManager
    @FocusState private var focusedId: String?
    @State private var banners: [APIBanner] = []
    @State private var playlists: [APIPlaylist] = []
    @State private var newSongs: [APISong] = []
    @State private var isLoading = true
    @State private var errorMsg: String?

    init(selection: Binding<String?>? = nil) {
        self._selection = selection ?? .constant("home")
    }

    let songColumns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        ScrollViewReader { verticalProxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    // MARK: - Title
                    Text("现在就听".localized)
                        .font(.system(size: 32, weight: .bold))
                        .padding(.horizontal, 28)
                        .padding(.top, 16)

                    if isLoading {
                        ProgressView("加载精彩内容...".localized)
                            .frame(maxWidth: .infinity, minHeight: 260)
                    } else if let err = errorMsg {
                        errorView(err)
                    } else {
                        // MARK: - 焦点推荐 Banners (Apple Music 顶部大卡片)
                        if !banners.isEmpty {
                            ScrollViewReader { bannerProxy in
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 20) {
                                        ForEach(Array(banners.enumerated()), id: \.offset) { idx, b in
                                            FeaturedBannerCard(
                                                banner: b,
                                                isFocused: focusedId == "banner_\(idx)"
                                            ) {
                                                focusedId = "banner_\(idx)"
                                                handleBannerClick(b)
                                            }
                                            .id("banner_\(idx)")
                                            .focusable()
                                            .focused($focusedId, equals: "banner_\(idx)")
                                            .focusEffectDisabled()
                                        }
                                    }
                                    .padding(.horizontal, 28)
                                    .scrollTargetLayout()
                                }
                                .onChange(of: focusedId) { _, newId in
                                    guard let newId, newId.hasPrefix("banner_") else { return }
                                    if let idx = Int(newId.replacingOccurrences(of: "banner_", with: "")) {
                                        let anchor: UnitPoint = (idx == 0) ? .leading : (idx == banners.count - 1 ? .trailing : .center)
                                        withAnimation(.easeInOut(duration: 0.28)) {
                                            bannerProxy.scrollTo(newId, anchor: anchor)
                                        }
                                    }
                                }
                            }
                            .id("section_banners")
                        }

                        // MARK: - 推荐歌单
                        if !playlists.isEmpty {
                            VStack(alignment: .leading, spacing: 14) {
                                sectionHeader("推荐歌单".localized)
                                ScrollViewReader { playlistProxy in
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 18) {
                                            ForEach(Array(playlists.enumerated()), id: \.offset) { idx, pl in
                                                PlaylistCard(
                                                    playlist: pl,
                                                    isFocused: focusedId == "playlist_\(idx)"
                                                ) {
                                                    focusedId = "playlist_\(idx)"
                                                    selection = "playlist_\(pl.id)"
                                                }
                                                .id("playlist_\(idx)")
                                                .focusable()
                                                .focused($focusedId, equals: "playlist_\(idx)")
                                                .focusEffectDisabled()
                                            }
                                        }
                                        .padding(.horizontal, 28)
                                        .scrollTargetLayout()
                                    }
                                    .onChange(of: focusedId) { _, newId in
                                        guard let newId, newId.hasPrefix("playlist_") else { return }
                                        if let idx = Int(newId.replacingOccurrences(of: "playlist_", with: "")) {
                                            let anchor: UnitPoint = (idx == 0) ? .leading : (idx == playlists.count - 1 ? .trailing : .center)
                                            withAnimation(.easeInOut(duration: 0.28)) {
                                                playlistProxy.scrollTo(newId, anchor: anchor)
                                            }
                                        }
                                    }
                                }
                            }
                            .id("section_playlists")
                        }

                        // MARK: - 新歌推荐 (双列 Apple Music 排版)
                        if !newSongs.isEmpty {
                            VStack(alignment: .leading, spacing: 14) {
                                sectionHeader("新歌速递".localized)
                                LazyVGrid(columns: songColumns, spacing: 4) {
                                    ForEach(Array(newSongs.prefix(12).enumerated()), id: \.offset) { idx, song in
                                        Button {
                                            focusedId = "song_\(idx)"
                                            player.play(song)
                                        } label: {
                                            NewSongRow(
                                                song: song,
                                                index: idx + 1,
                                                isFocused: focusedId == "song_\(idx)"
                                            )
                                        }
                                        .buttonStyle(.plain)
                                        .id("song_\(idx)")
                                        .focused($focusedId, equals: "song_\(idx)")
                                        .focusEffectDisabled()
                                    }
                                }
                                .padding(.horizontal, 28)
                            }
                            .id("section_newSongs")
                        }
                    }

                    Spacer(minLength: 90)
                }
            }
            .focusable()
            .focusEffectDisabled()
            .onChange(of: focusedId) { _, newId in
                guard let newId else { return }
                withAnimation(.easeInOut(duration: 0.28)) {
                    if newId.hasPrefix("banner_") {
                        verticalProxy.scrollTo("section_banners", anchor: .top)
                    } else if newId.hasPrefix("playlist_") {
                        verticalProxy.scrollTo("section_playlists", anchor: .center)
                    } else if newId.hasPrefix("song_") {
                        verticalProxy.scrollTo(newId, anchor: .center)
                    }
                }
            }
            .onKeyPress(.rightArrow) { moveFocus(direction: .right) }
            .onKeyPress(.leftArrow) { moveFocus(direction: .left) }
            .onKeyPress(.downArrow) { moveFocus(direction: .down) }
            .onKeyPress(.upArrow) { moveFocus(direction: .up) }
            .onKeyPress(.return) { activateFocusedItem(playOnly: false) }
            .onKeyPress(.space) { activateFocusedItem(playOnly: true) }
            .onKeyPress(.escape) {
                focusedId = nil
                return .handled
            }
        }
        .task { await loadData() }
    }

    // MARK: - Keyboard Navigation (方向键与回车流畅切换与滚动)

    enum FocusDirection {
        case left, right, up, down
    }

    private func moveFocus(direction: FocusDirection) -> KeyPress.Result {
        guard let current = focusedId else {
            // 没有当前焦点时，自动激活首个可用元素
            if !banners.isEmpty {
                focusedId = "banner_0"
                return .handled
            } else if !playlists.isEmpty {
                focusedId = "playlist_0"
                return .handled
            } else if !newSongs.isEmpty {
                focusedId = "song_0"
                return .handled
            }
            return .ignored
        }

        if current.hasPrefix("banner_") {
            guard let idx = Int(current.replacingOccurrences(of: "banner_", with: "")) else { return .ignored }

            switch direction {
            case .right:
                if idx + 1 < banners.count {
                    focusedId = "banner_\(idx + 1)"
                    return .handled
                }
            case .left:
                if idx - 1 >= 0 {
                    focusedId = "banner_\(idx - 1)"
                    return .handled
                }
            case .down:
                if !playlists.isEmpty {
                    // 下移保持相对列位置
                    let targetIdx = min(idx, playlists.count - 1)
                    focusedId = "playlist_\(targetIdx)"
                    return .handled
                } else if !newSongs.isEmpty {
                    focusedId = "song_0"
                    return .handled
                }
            case .up:
                return .ignored
            }
        } else if current.hasPrefix("playlist_") {
            guard let idx = Int(current.replacingOccurrences(of: "playlist_", with: "")) else { return .ignored }

            switch direction {
            case .right:
                if idx + 1 < playlists.count {
                    focusedId = "playlist_\(idx + 1)"
                    return .handled
                }
            case .left:
                if idx - 1 >= 0 {
                    focusedId = "playlist_\(idx - 1)"
                    return .handled
                }
            case .up:
                if !banners.isEmpty {
                    let targetIdx = min(idx, banners.count - 1)
                    focusedId = "banner_\(targetIdx)"
                    return .handled
                }
            case .down:
                if !newSongs.isEmpty {
                    let targetIdx = min(idx % 2, min(newSongs.count - 1, 11))
                    focusedId = "song_\(targetIdx)"
                    return .handled
                }
            }
        } else if current.hasPrefix("song_") {
            guard let idx = Int(current.replacingOccurrences(of: "song_", with: "")) else { return .ignored }
            let maxSongs = min(newSongs.count, 12)

            switch direction {
            case .right:
                if idx % 2 == 0 && idx + 1 < maxSongs {
                    focusedId = "song_\(idx + 1)"
                    return .handled
                }
            case .left:
                if idx % 2 == 1 {
                    focusedId = "song_\(idx - 1)"
                    return .handled
                }
            case .up:
                if idx - 2 >= 0 {
                    focusedId = "song_\(idx - 2)"
                    return .handled
                } else if !playlists.isEmpty {
                    focusedId = "playlist_0"
                    return .handled
                }
            case .down:
                if idx + 2 < maxSongs {
                    focusedId = "song_\(idx + 2)"
                    return .handled
                }
            }
        }

        return .ignored
    }

    private func activateFocusedItem(playOnly: Bool) -> KeyPress.Result {
        guard let current = focusedId else { return .ignored }

        if current.hasPrefix("banner_") {
            if let idx = Int(current.replacingOccurrences(of: "banner_", with: "")),
               idx >= 0 && idx < banners.count {
                handleBannerClick(banners[idx])
                return .handled
            }
        } else if current.hasPrefix("playlist_") {
            if let idx = Int(current.replacingOccurrences(of: "playlist_", with: "")),
               idx >= 0 && idx < playlists.count {
                let pl = playlists[idx]
                if playOnly {
                    playPlaylist(pl)
                } else {
                    selection = "playlist_\(pl.id)"
                }
                return .handled
            }
        } else if current.hasPrefix("song_") {
            if let idx = Int(current.replacingOccurrences(of: "song_", with: "")),
               idx >= 0 && idx < min(newSongs.count, 12) {
                let song = newSongs[idx]
                if playOnly && player.currentSong?.id == song.id {
                    player.togglePlay()
                } else {
                    player.play(song)
                }
                return .handled
            }
        }
        return .ignored
    }

    private func playPlaylist(_ playlist: APIPlaylist) {
        Task {
            do {
                let songs = try await NetworkManager.shared.playlistTracks(id: playlist.id, limit: 50)
                if !songs.isEmpty {
                    await MainActor.run {
                        player.playAll(songs)
                    }
                }
            } catch {
                print("加载歌单失败: \(error)")
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 22, weight: .bold))
            .padding(.horizontal, 28)
    }

    private func errorView(_ msg: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text(msg)
                .font(.headline)
                .foregroundStyle(.secondary)
            Button("重试".localized) { Task { await loadData() } }
                .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, minHeight: 260)
    }

    private func loadData() async {
        isLoading = true
        errorMsg = nil
        do {
            async let b = NetworkManager.shared.banner()
            async let p = NetworkManager.shared.personalizedPlaylists(limit: 10)
            async let n = NetworkManager.shared.personalizedNewSongs()
            let (fetchedBanners, fetchedPL, fetchedNS) = try await (b, p, n)
            banners = fetchedBanners
            playlists = fetchedPL
            newSongs = fetchedNS.compactMap(\.asAPISong)
        } catch {
            errorMsg = "无法连接到 API 服务\n请确认 127.0.0.1:3000 已启动".localized
            print("HomeView error: \(error)")
        }
        isLoading = false
    }

    // MARK: - Banner Click Handling

    private func handleBannerClick(_ banner: APIBanner) {
        // 1. 如果是单曲 (targetType == 1: 新歌首发)
        if banner.targetType == 1 {
            if let songId = banner.targetId, songId > 0 {
                Task {
                    do {
                        let songs = try await NetworkManager.shared.songDetail(ids: [songId])
                        if let song = songs.first {
                            await MainActor.run {
                                player.play(song)
                            }
                        }
                    } catch {
                        print("❌ 加载 Banner 单曲失败: \(error)")
                    }
                }
                return
            }
        }

        // 2. 如果是专辑 (targetType == 10: 新碟首发)
        if banner.targetType == 10 {
            if let albumId = banner.targetId, albumId > 0 {
                withAnimation(.easeInOut(duration: 0.22)) {
                    selection = "album_\(albumId)"
                }
                return
            }
        }

        // 3. 如果是歌单 (targetType == 1000)
        if banner.targetType == 1000 {
            if let plId = banner.targetId, plId > 0 {
                withAnimation(.easeInOut(duration: 0.22)) {
                    selection = "playlist_\(plId)"
                }
                return
            }
        }

        // 4. 如果是歌手 (targetType == 100)
        if banner.targetType == 100 {
            if let arId = banner.targetId, arId > 0 {
                withAnimation(.easeInOut(duration: 0.22)) {
                    selection = "artist_\(arId)"
                }
                return
            }
        }

        // 5. 解析 url 字段（网页外链或 orpheus 协议）
        if let urlStr = banner.url, !urlStr.isEmpty {
            // 5a. 如果是标准 Web 链接 (targetType == 3000 等独家策划、活动)
            if urlStr.hasPrefix("http://") || urlStr.hasPrefix("https://") {
                if let webURL = URL(string: urlStr) {
                    NSWorkspace.shared.open(webURL)
                }
                return
            }

            // 5b. 如果是 orpheus 协议 (orpheus://song/123, orpheus://album/123, etc.)
            if urlStr.hasPrefix("orpheus://") {
                let stripped = urlStr.replacingOccurrences(of: "orpheus://", with: "")
                let parts = stripped.split(separator: "/")
                if parts.count >= 2 {
                    let type = String(parts[0])
                    let idStr = String(parts[1])
                    if let id = Int(idStr) {
                        switch type {
                        case "song":
                            Task {
                                if let song = (try? await NetworkManager.shared.songDetail(ids: [id]))?.first {
                                    await MainActor.run { player.play(song) }
                                }
                            }
                            return
                        case "album":
                            withAnimation(.easeInOut(duration: 0.22)) {
                                selection = "album_\(id)"
                            }
                            return
                        case "playlist":
                            withAnimation(.easeInOut(duration: 0.22)) {
                                selection = "playlist_\(id)"
                            }
                            return
                        case "artist":
                            withAnimation(.easeInOut(duration: 0.22)) {
                                selection = "artist_\(id)"
                            }
                            return
                        default:
                            break
                        }
                    }
                }
            }
        }

        // 6. 兜底回退：如果 targetId > 0 但 targetType 未知，尝试根据类型标题推断
        if let targetId = banner.targetId, targetId > 0 {
            let title = banner.typeTitle ?? ""
            if title.contains("歌") || title.contains("单曲") {
                Task {
                    if let song = (try? await NetworkManager.shared.songDetail(ids: [targetId]))?.first {
                        await MainActor.run { player.play(song) }
                    }
                }
            } else if title.contains("碟") || title.contains("专辑") {
                withAnimation(.easeInOut(duration: 0.22)) {
                    selection = "album_\(targetId)"
                }
            } else if title.contains("歌单") {
                withAnimation(.easeInOut(duration: 0.22)) {
                    selection = "playlist_\(targetId)"
                }
            } else {
                print("⚠️ 未处理的 Banner: targetType=\(banner.targetType ?? -1), targetId=\(targetId), title=\(title)")
            }
        }
    }
}

// MARK: - Featured Banner Card (Apple Music 顶部焦点横幅卡片)

struct FeaturedBannerCard: View {
    let banner: APIBanner
    var isFocused: Bool = false
    var onSelect: (() -> Void)? = nil
    @Environment(ThemeManager.self) private var themeManager
    @State private var isHovering = false
    @State private var isLoading = false

    var body: some View {
        Button {
            triggerAction()
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                if let type = banner.typeTitle, !type.isEmpty {
                    Text(type)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(themeManager.accentColor)
                        .textCase(.uppercase)
                }

                ZStack(alignment: .bottomTrailing) {
                    AsyncImage(url: URL(string: banner.imageUrl)) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable()
                                .aspectRatio(contentMode: .fill)
                        default:
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.quaternary)
                                .overlay {
                                    Image(systemName: "photo")
                                        .font(.title)
                                        .foregroundStyle(.tertiary)
                                }
                        }
                    }
                    .frame(width: 380, height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(themeManager.accentColor, lineWidth: isFocused ? 2.5 : 0)
                    )

                    // 悬停时、获取焦点时或加载时的操作指示器
                    if isHovering || isFocused || isLoading {
                        badgeView
                            .padding(12)
                            .transition(.opacity.combined(with: .scale(scale: 0.85)))
                    }
                }
                .contentShape(RoundedRectangle(cornerRadius: 12))
                .shadow(
                    color: isFocused ? themeManager.accentColor.opacity(0.4) : .black.opacity(isHovering ? 0.22 : 0.1),
                    radius: isFocused ? 14 : (isHovering ? 12 : 8),
                    y: isFocused ? 2 : 4
                )
                .scaleEffect((isHovering || isFocused) ? 1.02 : 1.0)
            }
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .frame(width: 380)
        .onHover { h in withAnimation(.easeInOut(duration: 0.15)) { isHovering = h } }
    }

    private func triggerAction() {
        if banner.targetType == 1 {
            isLoading = true
            onSelect?()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                isLoading = false
            }
        } else {
            onSelect?()
        }
    }

    @ViewBuilder
    private var badgeView: some View {
        if isLoading {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 36, height: 36)
                    .shadow(color: .black.opacity(0.3), radius: 6, y: 2)
                ProgressView()
                    .controlSize(.small)
            }
        } else if banner.targetType == 1 {
            // 单曲：显示主题色播放图标
            ZStack {
                Circle()
                    .fill(themeManager.accentColor)
                    .frame(width: 36, height: 36)
                    .shadow(color: .black.opacity(0.3), radius: 6, y: 3)
                Image(systemName: "play.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.white)
                    .offset(x: 1)
            }
        } else if banner.targetType == 10 {
            // 专辑
            HStack(spacing: 5) {
                Image(systemName: "opticaldisc")
                Text("专辑".localized)
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
        } else if banner.targetType == 1000 {
            // 歌单
            HStack(spacing: 5) {
                Image(systemName: "music.note.list")
                Text("歌单".localized)
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
        } else if banner.targetType == 3000 || banner.url?.hasPrefix("http") == true {
            // 网页 / 活动
            HStack(spacing: 5) {
                Image(systemName: "safari")
                Text("活动".localized)
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
        }
    }
}

// MARK: - Playlist Card

struct PlaylistCard: View {
    let playlist: APIPlaylist
    var isFocused: Bool = false
    var onSelect: (() -> Void)? = nil
    @Environment(PlayerManager.self) private var player
    @Environment(ThemeManager.self) private var themeManager
    @State private var isHovering = false
    @State private var isPlayHovering = false
    @State private var isLoadingSongs = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                // 封面底层：点击进入歌单详情
                Button {
                    onSelect?()
                } label: {
                    AsyncImage(url: URL(string: playlist.displayCover ?? "")) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().aspectRatio(contentMode: .fill)
                        default:
                            Rectangle().fill(.quaternary)
                                .overlay(Image(systemName: "music.note.list").font(.title).foregroundStyle(.tertiary))
                        }
                    }
                    .frame(width: 170, height: 170)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(themeManager.accentColor, lineWidth: isFocused ? 2.5 : 0)
                    )
                }
                .buttonStyle(.plain)
                .shadow(
                    color: isFocused ? themeManager.accentColor.opacity(0.4) : .black.opacity(isHovering ? 0.18 : 0.1),
                    radius: isFocused ? 12 : (isHovering ? 10 : 6),
                    y: isFocused ? 2 : 4
                )
                .scaleEffect((isHovering || isFocused) ? 1.03 : 1.0)

                // 悬停时或获得焦点时显示快捷播放按钮 (顶层独立 Button，点击仅播放歌曲)
                if isHovering || isFocused {
                    Button {
                        loadAndPlay()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(themeManager.accentColor)
                                .frame(width: 38, height: 38)
                                .shadow(color: .black.opacity(0.35), radius: 6, y: 3)

                            if isLoadingSongs {
                                ProgressView()
                                    .controlSize(.small)
                                    .tint(.white)
                            } else {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(.white)
                                    .offset(x: 1.5)
                            }
                        }
                        .scaleEffect(isPlayHovering ? 1.08 : 1.0)
                    }
                    .buttonStyle(.plain)
                    .onHover { h in
                        withAnimation(.easeInOut(duration: 0.1)) {
                            isPlayHovering = h
                        }
                    }
                    .padding(10)
                    .transition(.opacity.combined(with: .scale(scale: 0.85)))
                }
            }
            .onHover { h in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovering = h
                }
            }

            // 歌单标题与播放量：点击进入歌单详情
            Button {
                onSelect?()
            } label: {
                VStack(alignment: .leading, spacing: 3) {
                    Text(playlist.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    if let count = playlist.playCount {
                        Text(formatCount(count) + " " + "次播放".localized)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
        .frame(width: 170)
    }

    private func loadAndPlay() {
        guard !isLoadingSongs else { return }
        isLoadingSongs = true
        Task {
            do {
                let songs = try await NetworkManager.shared.playlistTracks(id: playlist.id, limit: 50)
                if !songs.isEmpty {
                    player.playAll(songs)
                }
            } catch {
                print("加载歌单失败: \(error)")
            }
            isLoadingSongs = false
        }
    }

    private func formatCount(_ n: Int) -> String {
        if n >= 100_000_000 { return String(format: "%.1f亿", Double(n) / 100_000_000) }
        if n >= 10_000 { return String(format: "%.1f万", Double(n) / 10_000) }
        return "\(n)"
    }
}

// MARK: - New Song Row

struct NewSongRow: View {
    let song: APISong
    let index: Int
    var isFocused: Bool = false
    @Environment(PlayerManager.self) private var player
    @Environment(ThemeManager.self) private var themeManager
    @State private var isHovered = false

    var body: some View {
        let isCurrent = player.currentSong?.id == song.id

        HStack(spacing: 0) {
            // Index / Play Icon
            ZStack {
                if isCurrent {
                    Image(systemName: player.isPlaying ? "speaker.wave.2.fill" : "pause.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(themeManager.accentColor)
                } else if isHovered {
                    Image(systemName: "play.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.primary)
                } else {
                    Text("\(index)")
                        .font(.system(size: 12).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 28)

            // Cover
            AsyncImage(url: URL(string: song.coverUrl ?? "")) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().aspectRatio(contentMode: .fill)
                case .failure:
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.secondary.opacity(0.12))
                        .overlay(Image(systemName: "music.note").font(.system(size: 16)).foregroundStyle(.tertiary))
                default:
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.secondary.opacity(0.08))
                        .overlay(ProgressView().controlSize(.mini))
                }
            }
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .padding(.trailing, 10)

            // Title & Artist
            VStack(alignment: .leading, spacing: 3) {
                Text(song.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isCurrent ? themeManager.accentColor : .primary)
                    .lineLimit(1)

                Text(song.displayArtist)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if isHovered || player.isLiked(song.id) {
                Button {
                    player.toggleLike(for: song)
                } label: {
                    Image(systemName: player.isLiked(song.id) ? "heart.fill" : "heart")
                        .font(.system(size: 12))
                        .foregroundStyle(player.isLiked(song.id) ? themeManager.accentColor : .secondary)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 10)
            }

            Text(song.durationText)
                .font(.system(size: 12).monospacedDigit())
                .foregroundStyle(.secondary)
                .padding(.trailing, 4)
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isFocused ? themeManager.accentColor.opacity(0.14) : (isHovered ? Color.primary.opacity(0.05) : Color.clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(themeManager.accentColor, lineWidth: isFocused ? 1.5 : 0)
        )
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }
}

#Preview {
    HomeView()
        .environment(PlayerManager())
        .environment(ThemeManager.shared)
        .environment(LanguageManager.shared)
}
