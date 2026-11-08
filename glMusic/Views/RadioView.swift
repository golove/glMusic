//
//  RadioView.swift
//  glMusic
//
//  Created by go love on 10/29/26.
//

import SwiftUI

struct RadioView: View {
    @Binding var selection: String?
    @Environment(PlayerManager.self) private var player

    @State private var banners: [APIDJBanner] = []
    @State private var recommendedRadios: [APIDJRadio] = []
    @State private var topPrograms: [APIDJToplistItem] = []
    @State private var categories: [APIDJCategory] = []
    @State private var selectedCategoryId: Int? = nil  // nil = 热门推荐
    @State private var categoryRadios: [APIDJRadio] = []

    @State private var isLoading = true
    @State private var isLoadingCategory = false
    @State private var errorMsg: String?

    init(selection: Binding<String?>? = nil) {
        self._selection = selection ?? .constant("radio")
    }

    private let programColumns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    private let radioGridColumns = [
        GridItem(.adaptive(minimum: 160, maximum: 190), spacing: 20)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                // MARK: - 页面标题
                VStack(alignment: .leading, spacing: 6) {
                    Text("广播".localized)
                        .font(.system(size: 32, weight: .bold))

                    Text("全天候精选电台、深度对谈与精彩播客".localized)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 28)
                .padding(.top, 16)

                if isLoading {
                    ProgressView("正在调频广播频道...".localized)
                        .frame(maxWidth: .infinity, minHeight: 260)
                } else if let err = errorMsg {
                    errorView(err)
                } else {
                    // MARK: - 1. 焦点电台横幅 (Apple Music 顶部精选大卡片)
                    if !banners.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 20) {
                                ForEach(banners) { b in
                                    RadioBannerCard(banner: b) {
                                        playBannerProgram(b)
                                    }
                                }
                            }
                            .padding(.horizontal, 28)
                        }
                    }

                    // MARK: - 2. 精选电台推荐 (横向滑动卡片)
                    if !recommendedRadios.isEmpty {
                        VStack(alignment: .leading, spacing: 14) {
                            sectionHeader("热门电台推荐".localized)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 18) {
                                    ForEach(recommendedRadios) { radio in
                                        RadioStationCard(radio: radio) {
                                            selection = "radio_\(radio.id)"
                                        } onQuickPlay: {
                                            quickPlayRadio(radio)
                                        }
                                    }
                                }
                                .padding(.horizontal, 28)
                            }
                        }
                    }

                    // MARK: - 3. 热门广播节目 (双列 Apple Music 速递排版)
                    if !topPrograms.isEmpty {
                        VStack(alignment: .leading, spacing: 14) {
                            sectionHeader("热门广播节目".localized)
                            LazyVGrid(columns: programColumns, spacing: 8) {
                                ForEach(Array(topPrograms.prefix(8).enumerated()), id: \.element.id) { idx, item in
                                    RadioTopProgramRow(
                                        program: item.program,
                                        rank: idx + 1,
                                        isPlaying: player.currentSong?.id == item.program.mainSong?.id,
                                        onPlay: {
                                            if let song = item.program.asAPISong {
                                                player.play(song)
                                            }
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal, 28)
                        }
                    }

                    // MARK: - 4. 分类探索与电台网格
                    VStack(alignment: .leading, spacing: 16) {
                        sectionHeader("分类探索".localized)

                        // 分类切换胶囊
                        if !categories.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    categoryPill(title: "热门推荐".localized, isSelected: selectedCategoryId == nil) {
                                        selectCategory(nil)
                                    }

                                    ForEach(categories) { cat in
                                        categoryPill(title: cat.name, isSelected: selectedCategoryId == cat.id) {
                                            selectCategory(cat.id)
                                        }
                                    }
                                }
                                .padding(.horizontal, 28)
                            }
                        }

                        // 分类下的电台网格
                        if isLoadingCategory {
                            ProgressView()
                                .frame(maxWidth: .infinity, minHeight: 160)
                        } else {
                            let radiosToShow = selectedCategoryId == nil ? Array(recommendedRadios.dropFirst(4)) : categoryRadios
                            if !radiosToShow.isEmpty {
                                LazyVGrid(columns: radioGridColumns, spacing: 22) {
                                    ForEach(radiosToShow) { radio in
                                        RadioStationCard(radio: radio) {
                                            selection = "radio_\(radio.id)"
                                        } onQuickPlay: {
                                            quickPlayRadio(radio)
                                        }
                                    }
                                }
                                .padding(.horizontal, 28)
                            } else {
                                Text("该分类下暂无电台".localized)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 28)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                }

                Spacer(minLength: 90)
            }
        }
        .task { await loadData() }
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 20, weight: .bold))
            .padding(.horizontal, 28)
    }

    private func categoryPill(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isSelected ? Color.pink : Color.secondary.opacity(0.12))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func errorView(_ msg: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text(msg)
                .font(.headline)
                .foregroundStyle(.secondary)
            Button("重新加载".localized) { Task { await loadData() } }
                .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, minHeight: 260)
    }

    // MARK: - Data Loading

    private func loadData() async {
        isLoading = true
        errorMsg = nil
        do {
            async let b = NetworkManager.shared.djBanners()
            async let r = NetworkManager.shared.djRecommend()
            async let t = NetworkManager.shared.djProgramToplist(limit: 10)
            async let c = NetworkManager.shared.djCategories()

            let (fetchedBanners, fetchedRadios, fetchedTop, fetchedCats) = try await (b, r, t, c)
            banners = fetchedBanners
            recommendedRadios = fetchedRadios
            topPrograms = fetchedTop
            categories = fetchedCats
        } catch {
            errorMsg = "无法连接到广播服务\n请确认 127.0.0.1:3000 已启动".localized
            print("RadioView error: \(error)")
        }
        isLoading = false
    }

    private func selectCategory(_ catId: Int?) {
        guard selectedCategoryId != catId else { return }
        selectedCategoryId = catId

        if let catId = catId {
            isLoadingCategory = true
            Task {
                do {
                    let radios = try await NetworkManager.shared.djRadiosByCategory(typeId: catId)
                    await MainActor.run {
                        categoryRadios = radios
                        isLoadingCategory = false
                    }
                } catch {
                    print("❌ 加载分类电台失败: \(error)")
                    await MainActor.run { isLoadingCategory = false }
                }
            }
        }
    }

    // MARK: - Audio Playback

    private func playBannerProgram(_ banner: APIDJBanner) {
        guard let programId = banner.targetId, programId > 0 else { return }
        Task {
            do {
                if let program = try await NetworkManager.shared.djProgramDetail(id: programId),
                   let song = program.asAPISong {
                    await MainActor.run {
                        player.play(song)
                    }
                }
            } catch {
                print("❌ 播放 Banner 电台节目失败: \(error)")
            }
        }
    }

    private func quickPlayRadio(_ radio: APIDJRadio) {
        Task {
            do {
                let progs = try await NetworkManager.shared.djRadioPrograms(rid: radio.id, limit: 30)
                let songs = progs.compactMap(\.asAPISong)
                if !songs.isEmpty {
                    await MainActor.run {
                        player.playAll(songs, from: 0)
                    }
                }
            } catch {
                print("❌ 快速播放电台失败: \(error)")
            }
        }
    }
}

// MARK: - Radio Banner Card (焦点电台横幅)

struct RadioBannerCard: View {
    let banner: APIDJBanner
    var onSelect: (() -> Void)? = nil
    @State private var isHovering = false
    @State private var isLoading = false

    var body: some View {
        Button {
            isLoading = true
            onSelect?()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                isLoading = false
            }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                if let type = banner.typeTitle, !type.isEmpty {
                    Text(type)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.pink)
                        .textCase(.uppercase)
                }

                ZStack(alignment: .bottomTrailing) {
                    AsyncImage(url: URL(string: banner.displayPic ?? banner.pic?.httpsURL ?? "")) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().aspectRatio(contentMode: .fill)
                        case .empty:
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.primary.opacity(0.05))
                                ProgressView()
                                    .controlSize(.small)
                            }
                        default:
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.quaternary)
                                .overlay(Image(systemName: "dot.radiowaves.left.and.right").font(.largeTitle).foregroundStyle(.tertiary))
                        }
                    }
                    .frame(width: 380, height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // 悬停操作指示器
                    if isHovering || isLoading {
                        ZStack {
                            Circle()
                                .fill(isLoading ? Color.black.opacity(0.6) : Color.pink)
                                .frame(width: 40, height: 40)
                                .shadow(color: .black.opacity(0.3), radius: 6, y: 3)

                            if isLoading {
                                ProgressView()
                                    .controlSize(.small)
                                    .tint(.white)
                            } else {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 16))
                                    .foregroundStyle(.white)
                                    .offset(x: 1)
                            }
                        }
                        .padding(14)
                        .transition(.opacity.combined(with: .scale(scale: 0.85)))
                    }
                }
                .contentShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(isHovering ? 0.22 : 0.1), radius: isHovering ? 12 : 8, y: 4)
                .scaleEffect(isHovering ? 1.02 : 1.0)
            }
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .frame(width: 380)
        .onHover { h in withAnimation(.easeInOut(duration: 0.15)) { isHovering = h } }
    }
}

// MARK: - Radio Station Card (电台方形卡片)

struct RadioStationCard: View {
    let radio: APIDJRadio
    var onSelect: (() -> Void)? = nil
    var onQuickPlay: (() -> Void)? = nil

    @State private var isHovering = false
    @State private var isPlayHovering = false
    @State private var isLoadingPlay = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                // 封面
                Button {
                    onSelect?()
                } label: {
                    AsyncImage(url: URL(string: radio.displayCover ?? radio.picUrl ?? "")) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().aspectRatio(contentMode: .fill)
                        default:
                            Rectangle().fill(.quaternary)
                                .overlay(Image(systemName: "dot.radiowaves.left.and.right").font(.title).foregroundStyle(.tertiary))
                        }
                    }
                    .frame(width: 170, height: 170)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .contentShape(RoundedRectangle(cornerRadius: 10))
                .shadow(color: .black.opacity(isHovering ? 0.2 : 0.1), radius: isHovering ? 10 : 6, y: 4)
                .scaleEffect(isHovering ? 1.03 : 1.0)

                // 悬停快捷播放按钮
                if isHovering {
                    Button {
                        isLoadingPlay = true
                        onQuickPlay?()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                            isLoadingPlay = false
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(.pink)
                                .frame(width: 36, height: 36)
                                .shadow(color: .black.opacity(0.3), radius: 6, y: 3)
                                .scaleEffect(isPlayHovering ? 1.08 : 1.0)

                            if isLoadingPlay {
                                ProgressView()
                                    .controlSize(.small)
                                    .tint(.white)
                            } else {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.white)
                                    .offset(x: 1)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(10)
                    .onHover { ph in isPlayHovering = ph }
                    .transition(.opacity.combined(with: .scale(scale: 0.85)))
                }
            }
            .onHover { h in withAnimation(.easeInOut(duration: 0.15)) { isHovering = h } }

            // 标题与副标题
            VStack(alignment: .leading, spacing: 3) {
                Text(radio.name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)

                HStack(spacing: 4) {
                    if let cat = radio.category, !cat.isEmpty {
                        Text(cat)
                            .font(.system(size: 11))
                            .foregroundStyle(.pink)
                    }

                    if !radio.displaySubCount.isEmpty {
                        Text("· \(radio.displaySubCount)")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                .lineLimit(1)
            }
            .frame(width: 170, alignment: .leading)
        }
    }
}

// MARK: - Radio Top Program Row (热门广播节目行)

struct RadioTopProgramRow: View {
    let program: APIDJProgram
    let rank: Int
    let isPlaying: Bool
    var onPlay: (() -> Void)? = nil

    @State private var isHovered = false
    @Environment(PlayerManager.self) private var player

    var body: some View {
        HStack(spacing: 12) {
            // 排名
            Text("\(rank)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(rank <= 3 ? .pink : .secondary)
                .frame(width: 20, alignment: .center)

            // 封面与播放悬停
            ZStack {
                AsyncImage(url: URL(string: program.displayCover ?? program.coverUrl?.httpsURL ?? "")) { phase in
                    if let img = phase.image {
                        img.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        RoundedRectangle(cornerRadius: 6).fill(.quaternary)
                    }
                }
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 6))

                if isHovered || isPlaying {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.black.opacity(0.45))
                        .frame(width: 48, height: 48)

                    Image(systemName: isPlaying ? "speaker.wave.3.fill" : "play.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.white)
                }
            }

            // 节目名称与所属电台
            VStack(alignment: .leading, spacing: 3) {
                Text(program.name)
                    .font(.system(size: 13, weight: isPlaying ? .semibold : .medium))
                    .foregroundStyle(isPlaying ? .pink : .primary)
                    .lineLimit(1)

                Text(program.radio?.name ?? program.dj?.nickname ?? "广播电台".localized)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // 收听量与时长
            HStack(spacing: 8) {
                Text(program.displayListenerCount)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                Text(program.durationText)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }

            // 下载按钮
            if let song = program.asAPISong {
                DownloadButton(song: song)
                    .opacity(isHovered || DownloadManager.shared.isDownloaded(song.id) || DownloadManager.shared.isDownloading(song.id) ? 1.0 : 0.0)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ? Color.primary.opacity(0.04) : (isPlaying ? Color.pink.opacity(0.06) : Color.clear))
        )
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .onHover { h in isHovered = h }
        .onTapGesture {
            onPlay?()
        }
        .contextMenu {
            if let song = program.asAPISong {
                Button {
                    player.play(song)
                } label: {
                    Label("立即播放".localized, systemImage: "play.fill")
                }

                Button {
                    player.playNext(song)
                } label: {
                    Label("下一首播放".localized, systemImage: "text.insert")
                }

                Button {
                    player.addToPlaylist(song)
                } label: {
                    Label("添加到待播列表".localized, systemImage: "text.badge.plus")
                }

                Divider()

                if DownloadManager.shared.isDownloaded(song.id) {
                    Button {
                        DownloadManager.shared.revealInFinder(song.id)
                    } label: {
                        Label("在访达中显示".localized, systemImage: "folder")
                    }

                    Button(role: .destructive) {
                        DownloadManager.shared.deleteDownload(song.id)
                    } label: {
                        Label("删除已下载文件".localized, systemImage: "trash")
                    }
                } else {
                    Button {
                        DownloadManager.shared.downloadSong(song)
                    } label: {
                        Label("下载节目".localized, systemImage: "arrow.down.circle")
                    }
                }

                Divider()

                Button {
                    player.toggleLike(for: song)
                } label: {
                    Label((player.isLiked(song.id) ? "取消喜欢" : "喜欢此节目").localized,
                          systemImage: player.isLiked(song.id) ? "heart.slash" : "heart")
                }
            }
        }
    }
}
