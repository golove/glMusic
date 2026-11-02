//
//  RadioDetailView.swift
//  glMusic
//
//  Created by go love on 10/31/26.
//

import SwiftUI

struct RadioDetailView: View {
    let radioId: Int
    var onBack: (() -> Void)? = nil
    @Environment(PlayerManager.self) private var player

    @State private var radio: APIDJRadio?
    @State private var programs: [APIDJProgram] = []
    @State private var isLoading = true
    @State private var hoveredProgramId: Int?
    @State private var isShowingFullDesc = false

    private var songs: [APISong] {
        programs.compactMap(\.asAPISong)
    }

    var body: some View {
        ZStack(alignment: .top) {
            

            // MARK: - 内容滚动区域
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {

                    if isLoading {
                        ProgressView("正在加载电台节目...")
                            .frame(maxWidth: .infinity, minHeight: 220)
                    } else if programs.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "dot.radiowaves.left.and.right")
                                .font(.system(size: 40))
                                .foregroundStyle(.tertiary)
                            Text("暂无电台节目")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 220)
                    } else {
                        // 节目列表
                        LazyVStack(spacing: 0) {
                            ForEach(Array(programs.enumerated()), id: \.element.id) { idx, prog in
                                RadioProgramRow(
                                    program: prog,
                                    index: idx + 1,
                                    isPlaying: player.currentSong?.id == prog.mainSong?.id,
                                    isHovered: hoveredProgramId == prog.id,
                                    onPlay: {
                                        playProgram(at: idx)
                                    }
                                )
                                .onHover { h in hoveredProgramId = h ? prog.id : nil }
                                .onTapGesture(count: 2) {
                                    playProgram(at: idx)
                                }
                            }
                        }

                        // 电台简介与创作者信息
                        if let desc = radio?.displayDesc, !desc.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("电台介绍")
                                    .font(.headline)

                                Text(desc)
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(isShowingFullDesc ? nil : 4)

                                Button(isShowingFullDesc ? "收起" : "更多") {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        isShowingFullDesc.toggle()
                                    }
                                }
                                .buttonStyle(.plain)
                                .font(.system(size: 12))
                                .foregroundStyle(.pink)
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 28)
                        }

//                        Spacer(minLength: 100)
                    }
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                // MARK: - 顶部常驻固定导航栏
                if let onBack = onBack {
                    VStack(spacing: 0) {
                        HStack(alignment: .top) {
                            topPinnedBar(onBack: onBack)
                            headerSection
                                .padding(.top, 12)
                            Spacer()
                        }

                        // 列表表头
                        HStack(spacing: 0) {
                            Text("#").frame(width: 36, alignment: .center)
                            Text("节目名称").frame(maxWidth: .infinity, alignment: .leading)
                            Text("收听量").frame(width: 120, alignment: .leading)
                            Image(systemName: "clock").frame(width: 70, alignment: .trailing)
                            Text("").frame(width: 60)
                        }
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 6)

//                        Divider().padding(.horizontal, 24)
                    }
                    .background(.ultraThinMaterial)
                    .zIndex(2)
                }
            }
        }
        
        .task { await loadData() }
    }

    // MARK: - Top Pinned Bar
    private func topPinnedBar(onBack: @escaping () -> Void) -> some View {
        Button(action: onBack) {
            HStack(spacing: 4) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                Text("广播")
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.12), radius: 3, y: 1)
        }
        .buttonStyle(.plain)
        .padding(.leading, 24)
        .padding(.top, 8)
    }

    // MARK: - Header Section
    private var headerSection: some View {
        HStack(alignment: .top, spacing: 20) {
            // 电台封面
            AsyncImage(url: URL(string: radio?.displayCover ?? radio?.picUrl ?? "")) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill)
                default:
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.quaternary)
                        .overlay(Image(systemName: "dot.radiowaves.left.and.right").font(.largeTitle).foregroundStyle(.tertiary))
                }
            }
            .frame(width: 140, height: 140)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.2), radius: 8, y: 4)

            // 电台元信息
            VStack(alignment: .leading, spacing: 6) {
                // 分类徽标
                if let cat = radio?.category, !cat.isEmpty {
                    Text(cat)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.pink)
                        .textCase(.uppercase)
                }

                // 电台名称
                Text(radio?.name ?? "电台详情")
                    .font(.system(size: 22, weight: .bold))
                    .lineLimit(1)

                // 主播与订阅量
                HStack(spacing: 8) {
                    if let dj = radio?.dj {
                        if let avatar = dj.displayAvatar ?? dj.avatarUrl, let aURL = URL(string: avatar) {
                            AsyncImage(url: aURL) { phase in
                                if let img = phase.image {
                                    img.resizable().aspectRatio(contentMode: .fill)
                                } else {
                                    Circle().fill(.secondary.opacity(0.3))
                                }
                            }
                            .frame(width: 18, height: 18)
                            .clipShape(Circle())
                        }
                        Text(dj.nickname ?? "主播")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                    }

                    if let countText = radio?.displaySubCount, !countText.isEmpty {
                        Text("·")
                            .foregroundStyle(.tertiary)
                        Text(countText)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }

                    if let pCount = radio?.programCount, pCount > 0 {
                        Text("·")
                            .foregroundStyle(.tertiary)
                        Text("\(pCount) 期节目")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }

                // 播放控制按钮群
                PlaybackActionBar(songs: songs, playTitle: "播放全部")
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
    }

    // MARK: - Actions
    private func playProgram(at index: Int) {
        guard index >= 0 && index < songs.count else { return }
        player.playAll(songs, from: index)
    }

    private func loadData() async {
        isLoading = true
        do {
            async let detailFetch = NetworkManager.shared.djRadioDetail(rid: radioId)
            async let programsFetch = NetworkManager.shared.djRadioPrograms(rid: radioId, limit: 60)
            let (fetchedRadio, fetchedProgs) = try await (detailFetch, programsFetch)
            radio = fetchedRadio
            programs = fetchedProgs
        } catch {
            print("❌ 加载电台详情失败: \(error)")
        }
        isLoading = false
    }
}

// MARK: - Radio Program Row

struct RadioProgramRow: View {
    let program: APIDJProgram
    let index: Int
    let isPlaying: Bool
    let isHovered: Bool
    var onPlay: (() -> Void)? = nil

    @Environment(PlayerManager.self) private var player

    var body: some View {
        HStack(spacing: 0) {
            // 序号 / 播放动效
            ZStack {
                if isPlaying {
                    Image(systemName: "speaker.wave.3.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.pink)
                } else if isHovered {
                    Button {
                        onPlay?()
                    } label: {
                        Image(systemName: "play.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.pink)
                    }
                    .buttonStyle(.plain)
                } else {
                    Text("\(index)")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 36, alignment: .center)

            // 节目封面与名称
            HStack(spacing: 12) {
                AsyncImage(url: URL(string: program.coverUrl ?? "")) { phase in
                    if let img = phase.image {
                        img.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(.quaternary)
                    }
                }
                .frame(width: 38, height: 38)
                .clipShape(RoundedRectangle(cornerRadius: 6))

                VStack(alignment: .leading, spacing: 3) {
                    Text(program.name)
                        .font(.system(size: 13, weight: isPlaying ? .semibold : .regular))
                        .foregroundStyle(isPlaying ? .pink : .primary)
                        .lineLimit(1)

                    if let host = program.dj?.nickname {
                        Text(host)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.trailing, 16)

            // 收听量
            Text(program.displayListenerCount)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 120, alignment: .leading)

            // 时长
            Text(program.durationText)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .trailing)

            // 快捷操作 (下载 + 喜欢)
            HStack(spacing: 10) {
                if let song = program.asAPISong {
                    DownloadButton(song: song)
                        .opacity(isHovered || DownloadManager.shared.isDownloaded(song.id) || DownloadManager.shared.isDownloading(song.id) ? 1.0 : 0.0)

                    Button {
                        player.toggleLike(for: song)
                    } label: {
                        Image(systemName: player.isLiked(song.id) ? "heart.fill" : "heart")
                            .font(.system(size: 13))
                            .foregroundStyle(player.isLiked(song.id) ? .pink : .secondary)
                    }
                    .buttonStyle(.plain)
                    .opacity(isHovered || player.isLiked(song.id) ? 1.0 : 0.0)
                }
            }
            .frame(width: 60, alignment: .trailing)
        }
        .padding(.horizontal, 24)
        .frame(height: 52)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ? Color.primary.opacity(0.04) : (isPlaying ? Color.pink.opacity(0.06) : Color.clear))
                .padding(.horizontal, 16)
        )
        .contextMenu {
            if let song = program.asAPISong {
                Button {
                    player.play(song)
                } label: {
                    Label("立即播放", systemImage: "play.fill")
                }

                Button {
                    player.playNext(song)
                } label: {
                    Label("下一首播放", systemImage: "text.insert")
                }

                Button {
                    player.addToPlaylist(song)
                } label: {
                    Label("添加到待播列表", systemImage: "text.badge.plus")
                }

                Divider()

                if DownloadManager.shared.isDownloaded(song.id) {
                    Button {
                        DownloadManager.shared.revealInFinder(song.id)
                    } label: {
                        Label("在访达中显示", systemImage: "folder")
                    }

                    Button(role: .destructive) {
                        DownloadManager.shared.deleteDownload(song.id)
                    } label: {
                        Label("删除已下载文件", systemImage: "trash")
                    }
                } else {
                    Button {
                        DownloadManager.shared.downloadSong(song)
                    } label: {
                        Label("下载节目", systemImage: "arrow.down.circle")
                    }
                }

                Divider()

                Button {
                    player.toggleLike(for: song)
                } label: {
                    Label(player.isLiked(song.id) ? "取消喜欢" : "喜欢此节目",
                          systemImage: player.isLiked(song.id) ? "heart.slash" : "heart")
                }
            }
        }
    }
}
